task fastp {

    File input_fastq_r1
    File? input_fastq_r2

    String output_fastq_r1
    String? output_fastq_r2

    String output_json
    String output_html

    Int mean_quality
    Int required_length
    Int window_size

    Int? cpu 
    String? mem 

    command {

    fastp -i ${input_fastq_r1} \
          -o ${output_fastq_r1} \
          ${"-I " + input_fastq_r2} \
          ${"-O " + output_fastq_r2} \
          -j ${output_json} \
          -h ${output_html} \
          --thread ${cpu} \
          --cut_right \
          --cut_right_window_size ${window_size} \
          --cut_right_mean_quality ${mean_quality} \
          --length_required ${required_length} 

    }

    runtime {

      docker: "quay.io/biocontainers/fastp:0.20.0--hdbcaa40_0"    
      cpu: cpu
      requested_memory: mem

    }

    output {

      File json = output_json
      File html = output_html
      File trimmed_fastq_r1 = output_fastq_r1
      File? trimmed_fastq_r2 = output_fastq_r2

    }  

}

# FASTQC
task fastqc {
  
    File input_fastq_r1
    File? input_fastq_r2

    String out_report_r1
    String? out_report_r2 

    Int? cpu 
    String? mem 

    command {

      fastqc -t ${cpu} -o . \
             ${input_fastq_r1} ${input_fastq_r2}

    }

    runtime {

      docker: "biocontainers/fastqc:v0.11.5_cv4"    
      cpu: cpu
      requested_memory: mem

    }

    output {

      File report_r1 = out_report_r1
      File? report_r2 = out_report_r2

    }

}

# HISAT2
task hisat2 {
  
    File input_fastq_r1
    File? input_fastq_r2
    Boolean is_paired_end

    String index_path
    String index_prefix

    String output_sam
    String output_summary

    String? sample_id
    String? platform 
    String? center 

    Int? cpu 
    String? mem 
    
    String opt_fastq_r1 = if (is_paired_end) then "-1" else "-U"

    command {

      hisat2 -p ${cpu} -x ${index_path}/${index_prefix} \
             --new-summary --summary-file ${output_summary} \
             ${opt_fastq_r1} ${input_fastq_r1} \
             ${"-2 " + input_fastq_r2} \
             --rg-id ${sample_id} --rg SM:${sample_id} \
             --rg LB:Fragment --rg PL:${platform} \
             --rg CN:${center} --rg PU:${sample_id} > ${output_sam}

    }

    runtime {

      docker: "quay.io/biocontainers/hisat2:2.1.0--py27h6bb024c_3"    
      cpu: cpu
      requested_memory: mem
      docker_volume: index_path

    }

    output {

      File summary = output_summary
      File sam = output_sam

    }

}

# SAM2BAM
task sam2bam {
  
    File input_sam
    String output_bam

    Int? cpu 
    String? mem 

    command {

      samtools sort ${input_sam} --threads ${cpu} -O BAM -o ${output_bam}

    }

    runtime {

      docker: "quay.io/biocontainers/samtools:1.9--h8571acd_11"    
      cpu: cpu
      requested_memory: mem

    }

    output {

      File bam = output_bam

    }

}

# STAR
task star {
  
    File input_fastq_r1
    File? input_fastq_r2
    String? compression

    String index_path

    String output_prefix

    Int? cpu 
    String? mem 

    String opt_compression = if (compression == ".gz") then "--readFilesCommand zcat" else ""

    command {

      STAR --runThreadN ${cpu} \
           --genomeDir ${index_path} \
           --readFilesIn ${input_fastq_r1} ${input_fastq_r2} \
           ${opt_compression} \
           --outSAMtype BAM SortedByCoordinate \
           --outFileNamePrefix ${output_prefix}

    }

    runtime {

      docker: "quay.io/biocontainers/star:2.7.2b--0"  
      cpu: cpu
      requested_memory: mem
      docker_volume: index_path

    }

    output {

      File summary = "${output_prefix}Log.final.out"
      File bam = "${output_prefix}Aligned.sortedByCoord.out.bam"

    }

}

# SALMON
task salmon {
  
    File input_fastq_r1
    File? input_fastq_r2
    Boolean is_paired_end

    String index_path

    String? library_type

    String output_dir

    Int? cpu 
    String? mem 

    String opt_fastq_r1 = if (is_paired_end) then "-1" else "-r"

    command {

      salmon quant -p ${cpu} -i ${index_path} -l ${library_type} \
                       ${opt_fastq_r1} ${input_fastq_r1} \
                       ${"-2 " + input_fastq_r2} \
                       -o ${output_dir}

    }

    runtime {

      docker: "quay.io/biocontainers/salmon:0.13.0--h86b0361_2"
      cpu: cpu
      requested_memory: mem
      docker_volume: index_path

    }

    output {

      File quant = "${output_dir}/quant.sf"

    }

}

# FEATURECOUNTS
task featureCounts {
  
    Array[File?] input_alignments

    File gtf

    String output_counts

    Int? cpu 
    String? mem 

    command {

      featureCounts -T ${cpu} -a ${gtf} -o ${output_counts}.raw ${sep=' ' input_alignments}
      
      # format count matrix
      sed -r 's#[^\t]+/([^\/\t]+)\.[bs]am#\1#g' ${output_counts}.raw | sed -r 's#Aligned\.sortedByCoord\.out##g' | sed '1d' | cut -f 1,7- > ${output_counts}

    }

    runtime {

      docker: "quay.io/biocontainers/subread:1.6.4--h84994c4_1"
      cpu: cpu
      requested_memory: mem

    }

    output {

      File counts = output_counts
      File summary = "${output_counts}.raw.summary"

    }

}

# ENSEMBLDB TX2GENE
task ensemblTx2Gene {

    File ensembldb_script
  
    File gtf   
    String output_tx2gene

    String? job_id
    Int? cpu 
    String? mem 
    
    command {

      Rscript ${ensembldb_script} --gtf ${gtf} \
      --outFile ${output_tx2gene}

    }

    runtime {

      docker: "quay.io/biocontainers/bioconductor-ensembldb:2.6.3--r351_0"    
      cpu: cpu
      requested_memory: mem

    }

    output {

      File tx2gene = output_tx2gene

    }

}

# TXIMPORT
task tximport {

    Array[File?] quant_files
    File? tx2gene 
    String output_counts
    String quant_tool
    Array[String] sample_ids
    File tximport_script

    Int? cpu 
    String? mem 
    
    command {

      Rscript ${tximport_script} --tx2gene ${tx2gene} \
      --quantFiles ${sep=',' quant_files} \
      --sampleIds ${sep=',' sample_ids} \
      --outFile ${output_counts} 
    
    }

    runtime {

      docker: "quay.io/biocontainers/bioconductor-tximport:1.10.0--r351_0"  
      cpu: cpu
      requested_memory: mem

    }

    output {

      File counts = output_counts

    }

}

# EDGER
task edgeR {
  
    File? counts
    Array[String] samples
    Array[String] group
    Int? min_counts
    
    File edger_script

    Int? cpu 
    String? mem 

    command {

      Rscript ${edger_script} --counts ${counts} \
      --samples ${sep=',' samples} \
      --group ${sep=',' group} \
      --minCounts ${min_counts} 
    
    }

    runtime {

      docker: "quay.io/biocontainers/bioconductor-edger:3.28.0--r36he1b5a44_0"    
      cpu: cpu
      requested_memory: mem

    }

    output {

        File diff_expr = "differential_expression.tsv"
        File logcpms = "logCPMs.tsv"
        File logcpms_hipathia = "logCPMs_hipathia.rds"

    }


}

# HIPATHIA
task hipathia {
  
    File? cpm_file
    Array[String] samples
    Array[String] group
    
    Boolean normalize_by_length
    Boolean do_vc

    Array[File?] input_vcfs
    Float? ko_factor
    
    File hipathia_script

    Int? cpu 
    String? mem 

    command {
      
      Rscript ${hipathia_script} --cpmFile ${cpm_file} \
      --samples ${sep=',' samples} \
      --group ${sep=',' group} \
      --normalizeByLength ${normalize_by_length} \
      --doVc ${do_vc} \
      --filteredVariants ${sep = "," input_vcfs} \
      --koFactor ${ko_factor}
    
    }

    runtime {

      docker: "quay.io/biocontainers/bioconductor-hipathia:2.2.0--r36_0"    
      cpu: cpu
      requested_memory: mem

    }

    output {

        File diff_signaling = "differential_signaling.tsv"
        File path_values = "path_values.tsv"
        File? ko_matrix = "ko_matrix.tsv"

    }

}

# VEP
task vep {

    File vcf_file

    # [0 most deleterious, 1 least deleterious]
    Float sift_cutoff
    # [1 most damaging, 0 least damaging]
    Float polyphen_cutoff

    String cache_dir
    String output_file

    Int? cpu 
    String? mem 
    
    command {

      /opt/vep/src/ensembl-vep/vep --dir_cache ${cache_dir} --offline --sift s --polyphen s --fork ${cpu} -i ${vcf_file} -o variants_annotated.txt

      /opt/vep/src/ensembl-vep/filter_vep -i variants_annotated.txt -o ${output_file} -f "SIFT < ${sift_cutoff} and PolyPhen > ${polyphen_cutoff}"
    
    }

    runtime {

      docker: "ensemblorg/ensembl-vep:release_99.1" 
      docker_volume: cache_dir
      cpu: cpu
      requested_memory: mem

    }

    output {

      File output_vcf = output_file
      
    }

}

# report
task report {

    File rmd_file
    File r_script

    File differential_expression
    File differential_signaling

    Boolean do_vc
    File? ko_matrix
    Float? ko_factor

    String output_file

    Int? cpu 
    String? mem 
    
    command {

      Rscript ${r_script} --rmdFile ${rmd_file} \
      --outFile ${output_file} \
      --outDir $PWD \
      --diffExprFile ${differential_expression} \
      --diffSignFile ${differential_signaling} \
      --doVc ${do_vc} \
      --koMat ${ko_matrix} \
      --koFactor ${ko_factor}
    
    }

    runtime {

      docker: "rocker/verse:3.6.2" 
      cpu: cpu
      requested_memory: mem

    }

    output {

      File output_report = output_file
      
    }

}