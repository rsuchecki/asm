queries = Channel.fromPath(params.query).splitFasta( by: 100000, file: true, compress: true )
refs = Channel.fromPath(params.target)


process mmIndex {
  input:
    file(ref) from refs

  output:
    file(mmi) into mmis

  script:
  """
  minimap2 -I 40G -d mmi ${ref}
  """
}

process mmap {
  label 'minimap2'
  label 'samtools'

  input:
    set file(mmi), file(query) from mmis.combine(queries)

  output:
    file(bam) into bams

  script:
  """
  minimap2 -a ${mmi} ${query} | samtools view -hbF 2304 > bam
  """
}

process postprocess {
  input:
    file(bam) from bams.collect()

  script:
  """
  ls -lh
  """
}