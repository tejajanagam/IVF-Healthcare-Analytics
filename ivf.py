import pandas as pd
from sqlalchemy import create_engine

csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data.csv"
engine = create_engine("mysql+pymysql://root:6305910074@localhost:3306/ivf1")
raw_table = "raw_table"


df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data.csv", encoding="latin1")


df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(raw_table, engine, if_exists="replace", index=False)


                                       #2

csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data2.csv"
table2="table2"
df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data2.csv", encoding="latin1")

df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(table2, engine, if_exists="replace", index=False)



                                       #3
csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data3.csv"
table3="table3"
df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data3.csv", encoding="latin1")

df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(table3, engine, if_exists="replace", index=False)


                                        #4
                                        
csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1a.csv"
table4="table4"
df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1a.csv", encoding="latin1")

df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(table4, engine, if_exists="replace", index=False)

                                      #5
                                
csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1b.csv"
table5="table5"
df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1b.csv", encoding="latin1")

df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(table5, engine, if_exists="replace", index=False)


                                      #6
                                     
csv_path = r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1c.csv"
table6="table6"
df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1c.csv", encoding="latin1")

df.columns = (
    df.columns
    .str.strip()                 
    .str.replace(r'[^0-9a-zA-Z_]+', '_', regex=True)  
    .str.replace('__+', '_', regex=True)  
    .str.lower()
    .str[:60]                    
)

df.to_sql(table6, engine, if_exists="replace", index=False)






















