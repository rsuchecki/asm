#!/usr/bin/env nextflow

import static groovy.json.JsonOutput.*
def helpMessage() {
  log.info"""
  =============================================================
  rsuchecki/asm  ~  version ${params.version}
  =============================================================
  Usage:

  nextflow run rsuchecki/asm

  Default params:
  """.stripIndent()
  println(prettyPrint(toJson(params)))
}

// Show help message
params.help = false
if (params.help){
    helpMessage()
    exit 0
}

queries = Channel.fromPath(params.query).splitFasta( by: params.chunk, file: true, compress: true )
 // .filter { record -> record.desc == "200" } // (record.desc as Integer) >= (params.minLength as Integer)	 }

ref = Channel.fromPath(params.target).first()
fai = Channel.fromPath(params.fai).first()


process mmIndex {
  echo true
  label 'minimap2'
  memory '80GB'
  cpus 10

  input:
    file(ref)

  output:
    file(mmi) into mmis

  script:
  """
  module list
  minimap2 -t ${task.cpus} -I 40G -d mmi ${ref}
  """
}

process mmap {
  memory '40GB'
  cpus 6
  echo true


  input:
    set file(mmi), file(query) from mmis.combine(queries)
 //   file(ref)

  output:
    file("*.bam") into bams

  script:
  """
  module list
  minimap2 --MD -t ${task.cpus} -a ${mmi} ${query} \
  | samtools view -hbF 2304 \
  > ${query}.bam
  """
  // | samtools calmd --threads ${task.cpus} -b - ${ref} \
}


process mergesort {
  memory '40GB'
  cpus 6
  label 'samtools'
  label 'results'


  input:
    file("*.bam") from bams.collect()

  output:
    file("final.bam") into mergedSortedBAM
    file("final.bam.bai")
    // file("sorted.bam") into mergedsorted

  script:
  """
  samtools merge -u - *.bam \
  | samtools sort --threads ${task.cpus} -o final.bam -
  samtools index final.bam
  """
}

process bam2bw {
  memory '8GB'
  cpus 6
  label 'results'
  //scratch=true

  input:
    file("final.bam") from mergedSortedBAM
    file(ref)
    file(fai)

  output:
    file("final.bw")

  script:
  """
  samtools depth -Q 1 --reference ${ref} final.bam | depth2bedgraph.awk > bedgraph
  cut -f1,2 ${fai} > chrsizes
  bedGraphToBigWig bedgraph chrsizes final.bw
  """

}


// process calmd {
//   label 'samtools'
//   label 'results'
//   cpus 10

//   input:
//     file("sorted.bam") from mergedsorted
//     file(ref) from refs2

//   script:
//   """
//   samtools calmd --threads ${task.cpus} -b sorted.bam ${ref} > calmd.bam
//   samtools index clamd.bam
//   """
// }