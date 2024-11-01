inputdir = config["input"]
outputdir = config["output"]
#expand("{out}/filtered.fam", out=config["output"], prefix=input_files.prefix)

if inputdir[-1] == "/":
    inputdir = inputdir[:-1]
#    print(inputdir)
if outputdir[-1] == "/":
    outputdir = outputdir[:-1]

input_files =  glob_wildcards(f"{inputdir}/{{prefix, [^/]+}}.fam")


def expand_chromosomes(number_of_chrs):
    chromosomes_ = [str(i) for i in range(1, int(number_of_chrs)+1)]
    chromosomes = [str(item).zfill(2) for item in chromosomes_]
    return(chromosomes)

def get_chr_nr(sp):
    if sp == "cow":
        return(29)
    if sp == "pig":
        return(18)
    if sp == "sheep":
        return(26)
    if sp == "goat":
        return(29)
    if sp == "dog":
        return(38)
    if sp == "cat":
        return(18)
    if sp == "alpaca":
        return(36)


rule all:
    input:
        expand("{out}/{prefix}_homozygosity.csv", prefix=input_files.prefix, out=config["output"]),
        expand("{out}/{prefix}_founder.hom", prefix=input_files.prefix, out=config["output"]),
        expand("{out}/{prefix}_all_common.csv", prefix=input_files.prefix, out=config["output"]),
        expand("{out}/{prefix}_common_without_paternal_homozygosity.csv", prefix=input_files.prefix, out=config["output"]),
        expand("{out}/{prefix}_plot.pdf", prefix=input_files.prefix, out=config["output"]),
#expand("{out}/locations_{prefix}.csv",prefix=input_files.prefix,  out=config["output"]), 

rule extract_x:
    message:
        """extracting X chromosome from input and filtering"""
    input:
        snp = f"{inputdir}/{{prefix}}.bed", 
        lgen = f"{inputdir}/{{prefix}}.bim", 
        sample = f"{inputdir}/{{prefix}}.fam"
    output:
        bam = outputdir + "/{prefix}_filtered.bed",
        bim = outputdir + "/{prefix}_filtered.bim",
        fam = outputdir + "/{prefix}_filtered.fam"
    params:
        name = lambda wc :  f"{inputdir}/{wc.prefix}",
        output =  outputdir + "/{prefix}_filtered",
        chrs = get_chr_nr(config["species"]),
        maf = config["filter"]["maf"],
        mind = config["filter"]["mind"],
        geno = config["filter"]["geno"],
        mendel = config["filter"]["me"]
    resources:
        mem="900M",
        time="00:02:10",
        cpus=1
    shell:
        """
        module load PLINK 
        plink --chr X --mendel-duos --prune --maf {params.maf} --mind {params.mind} --me {params.mendel} --geno {params.geno} --bfile {params.name} --out {params.output} --make-bed --chr-set {params.chrs}
        """
    
rule recode:
    message:
        """Recode bim, bam and fam to ped"""
    input:
        input_ = rules.extract_x.output.bim
    output:
        output = ("{outputdir}/{prefix}_recoded.ped"),
        map_ = ( "{outputdir}/{prefix}_recoded.map")
    params:
        input_ =  "{outputdir}/{prefix}_filtered",
        output =  "{outputdir}/{prefix}_recoded",
        chrs = get_chr_nr(config["species"])
    resources:
        mem="900M",
        time="00:05:05",
        cpus=1
    shell:
        """
        module load PLINK 
        plink --recode 12 --bfile {params.input_} --out {params.output} --chr-set {params.chrs} --tab 
        """

rule rename_genes:
    message:
        """ Renaming genes to standardised format.  map  -> csv """
    input:
        input_ = "{outputdir}/{prefix}_filtered.bim"
    output:
        filtered_csv = "{outputdir}/{prefix}_filtered.csv"
    resources:
        mem="4G",
        time="00:06:06",
        cpus=1
    shell:
        """
        python3 code/rename_genes.py \
        --input {input.input_} \
        --output {output.filtered_csv}
        """


rule extract_positive_cases:
    message:
        """Writing positive cases to separate file"""
    input:
        ped = rules.recode.output.output,
        fam = outputdir + "/{prefix}_filtered.fam"
    output:
        haplotypes = "{outputdir}/{prefix}_X_output.csv"
    params:
        folder = "{outputdir}/",
    resources:
        mem="20G",
        time="00:10:00",
        cpus=3
    shell:
        """
        python3 code/positive_cases.py \
        --ped {input.ped} \
        --output {output.haplotypes} \
        --fam {input.fam} 
        """


rule rewrite_haplotypes:
    message:
        """Finding linked locations..."""
    input:
        haplotype = rules.extract_positive_cases.output.haplotypes,
        map_ = rules.rename_genes.output
    output:
        linked = ("{outputdir}/{prefix}_locations_X.csv")
    params:
        min_length = config['variants']['min_var_length'],
        n_fraction_max = config["variants"]["n_fraction_max"],
        fuse_adjacent = config["variants"]["fuse_adjacent"],
        fuse_adjacent_nr = config["variants"]["fuse_adjacent_nr"],
        min_markers = config["variants"]["min_markers"],
        chrs = 39
    resources:
        mem="10G",
        time="00:05:06",
        cpus=2
    shell:
        """
        echo "CHR;BP1;BP2\n" >> {output.linked}
        python3 code/common_locations.py \
        --map {input.map_} \
        --hapl {input.haplotype} \
        --min_markers {params.min_markers} \
        --length {params.min_length} \
        --chr {params.chrs} \
        --n_fraction_max {params.n_fraction_max} \
        --fuse_adjacent {params.fuse_adjacent} \
        --fuse_adjacent_nr {params.fuse_adjacent_nr} \
        --output {output.linked} 
        """

rule filter_founder:
    message:
        """Writing file to filter for founders"""
    input:
        rules.extract_x.output.fam
    output:
        "{outputdir}/{prefix}_IDlist.txt"
    resources:
        mem="900M",
        time="00:05:04",
        cpus=1
    shell:
        """
        python3 code/founder.py \
        --input {input} \
        --output {output}
        """
        
rule founder:
    message:
        """Filtering non-founder data based on provided ID list"""
    input:
        input_ =  "{outputdir}/{prefix}_recoded.map",
        ids_to_remove = rules.filter_founder.output
    output:
        output = "{outputdir}/{prefix}_founder.bed"
    params:
        in_ =  "{outputdir}/{prefix}_recoded",
        out = "{outputdir}/{prefix}_founder",
        chrs = get_chr_nr(config["species"])
    resources:
        mem="900M",
        time="00:05:04",
        cpus=1
    shell:
        """
        module load PLINK 
        plink --file {params.in_} --remove {input.ids_to_remove} --out {params.out} --make-bed --chr-set {params.chrs} 
        """
        
rule homozygosity:
    message:
        """Find homozygous locations based on founder data"""
    input:
        input = rules.founder.output.output
    output:
        output = "{outputdir}/{prefix}_founder.hom"
    params:
        input_ = "{outputdir}/{prefix}_founder",
        output = "{outputdir}/{prefix}_founder",
        chrs = get_chr_nr(config["species"]),
        density = config["homozygosity_params"]["density"],
        kb = config["homozygosity_params"]["kb"],
        snp = config["homozygosity_params"]["snp"],
        window_missing = config["homozygosity_params"]["window_missing"],
        window_snp = config["homozygosity_params"]["window_snp"]
    resources:
        mem="900M",
        time="00:05:03",
        cpus=1
    shell:
        """
        module load PLINK 
        plink --bfile {params.input_} --homozyg --chr-set {params.chrs} --homozyg-density {params.density} --homozyg-kb {params.kb} --homozyg-snp {params.snp} --homozyg-window-missing {params.window_missing} --homozyg-window-snp {params.window_snp} --out {params.output}
        """

rule reformat_homozygosity:
    message:
        """Reformatting homozygous areas to a csv file for annotation"""
    input:
        input_ = rules.homozygosity.output
    output:
        output =  "{outputdir}/{prefix}_homozygosity.csv"
    resources:
        mem="500M",
        time="00:05:05",
        cpus=1
    shell:
        """
        python3 code/homozygosity.py \
        --input {input.input_} \
        --output {output.output}
        """

rule output_table:
    message:
        """Finding variants which are not homozygous in the paternal genome"""
    input:
        homozygous = rules.reformat_homozygosity.output,
        linked = rules.rewrite_haplotypes.output
    output:
        table =  "{outputdir}/{prefix}_common_without_paternal_homozygosity.csv",
        all_common = "{outputdir}/{prefix}_all_common.csv"
    resources:
        mem="500M",
        time="00:05:04",
        cpus=1
    shell:
        """
        python3 code/write_tables.py \
        --homozygosity {input.homozygous} \
        --linked {input.linked} \
        --with_homozyg {output.all_common} \
        --common {output.table}
        """

rule plot:
    message:
        """constructing chromosome map plot with homozygosity and linked haplotypes"""
    input:
        linked = rules.rewrite_haplotypes.output,
        chr_map = "chr_maps/" + config['species'] + "_chr_map.csv",
        homozyg = rules.reformat_homozygosity.output,
    output:
        plot = "{outputdir}/{prefix}_plot.pdf"
    resources:
        mem="500M",
        time="00:05:05",
        cpus=1
    params:
        chrs = get_chr_nr(config["species"])+1
    shell:
        """
        module load matplotlib
        python3 code/plot.py \
        --chr_file {input.chr_map} \
        --chr_nr {params.chrs} \
        --linked {input.linked} \
        --homozyg {input.homozyg} \
        --plot {output.plot}
        """


 