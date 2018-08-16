queries = Channel.fromPath(params.query).splitFasta( by: params.chunk, file: true, compress: true )
 // .filter { record -> record.desc == "200" } // (record.desc as Integer) >= (params.minLength as Integer)	 }

ref = Channel.fromPath(params.target).first()


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
  memory '34GB'
  cpus 6
  echo true


  input:
    set file(mmi), file(query) from mmis.combine(queries)
    file(ref)

  output:
    file("*.bam") into bams

  script:
  """
  module list
  minimap2 -t ${task.cpus} -a ${mmi} ${query} \
  | samtools view -hbF 2304 \
  | samtools calmd --threads ${task.cpus} -b - ${ref} \
  > ${query}.bam
  """
}

process postprocess {
  label 'samtools'
  label 'results'
  cpus 10

  input:
    file("*.bam") from bams.collect()

  output:
    file("*")
    // file("sorted.bam") into mergedsorted

  script:
  """
  samtools merge -u - *.bam \
  | samtools sort --threads ${task.cpus} -o final.bam -
  samtools index final.bam
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