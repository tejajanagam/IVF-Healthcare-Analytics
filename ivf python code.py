#Data preprocessing steps

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

df = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data.csv",encoding="latin1")

df.head()

df.tail()

df.shape

df.info()

df.isnull().sum() 

df.duplicated().sum() # 0 duplicated values

df.describe()
df.describe(include=[np.number])

#striping column names
df.columns = (
    df.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

categorical_cols = df.select_dtypes(include='object').columns

#check unique values
for col in categorical_cols:
    print(f"\n{col}")
    print(df[col].value_counts(dropna=False).head())

#boxplot
df.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


df_raw = df.copy()

df.drop(columns=['patient_name_and_surname'], inplace=True)

#clean
df['clinical_pregnancy'] = (
    df['clinical_pregnancy']
    .replace({'N': 0, '1(0)': 1})
    .astype(int)
)

df['abortion'] = df['abortion'].replace('', np.nan)

#typecasting
num_cols = [
    'e2',
    'progesterone',
    'number_of_oocytes',
    'endometrial_thickness_on_the_day_of_transfer',
    'bhcg_12_14percent_increase'
]

for col in num_cols:
    df[col] = pd.to_numeric(df[col], errors='coerce')

#missing values using median for numeric data
numeric_cols = df.select_dtypes(include=np.number).columns

for col in numeric_cols:
    df[col].fillna(df[col].median(), inplace=True)


#for categorical data
categorical_cols = df.select_dtypes(include='object').columns

for col in categorical_cols:
    df[col].fillna(df[col].mode()[0], inplace=True)

#outlier analysis
for col in numeric_cols:
    Q1 = df[col].quantile(0.25)
    Q3 = df[col].quantile(0.75)
    IQR = Q3 - Q1

    lower = Q1 - 1.5 * IQR
    upper = Q3 + 1.5 * IQR

    df[col] = np.where(df[col] < lower, lower,
                        np.where(df[col] > upper, upper, df[col]))


df.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data_cleaned.csv",
    index=False,
    encoding="utf-8-sig"
)

#EDA


eda_summary = pd.DataFrame({
    'Mean': df[num_cols].mean(),
    'Median': df[num_cols].median(),
    'mode': df[num_cols].mode(),
    'Std_Deviation': df[num_cols].std(),
    'Skewness': df[num_cols].skew(),
    'Kurtosis': df[num_cols].kurtosis()
})

eda_summary


#autoeda
#pip install dtale
import pandas as pd
import dtale
df = pd.read_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data_cleaned.csv",
    encoding="latin1"
)
d = dtale.show(df)
d.open_browser()



import seaborn as sns
import matplotlib.pyplot as plt

cols = [
   
    'e2',
    'progesterone',
    'number_of_oocytes',
   
]

df_multi = df[cols].dropna()

sns.pairplot(df_multi)
plt.show()

















