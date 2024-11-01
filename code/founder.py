import pandas as pd
import numpy as np
import argparse

def rm_val(lst,  val):
   return [value for value in lst if value != val]

def find_founder(inputfile, outputfile):
    df = pd.read_csv(inputfile, sep=" ", header=None)
    df.columns = ["family", "ID", "father", "mother", "a", "b"]
    print(df)
    mother_IDs = list(set(df.mother.values.tolist()))
    mother_ID = rm_val(mother_IDs, "0")
    print(mother_ID)
    output_df = df[~df["ID"].isin([mother for mother in mother_ID])]
    print(output_df)
    output_df = output_df.drop(["father", "mother", "a", "b"], axis=1)
    output_df.to_csv(outputfile, index=False, header=False, sep=" ")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description="Writing founder data to separate file",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument("--input", required=True, help=".fam file")
    parser.add_argument("--output", required=True, help=".txt file")
    args = parser.parse_args()

    find_founder(args.input, args.output)