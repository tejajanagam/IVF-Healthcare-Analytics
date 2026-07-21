import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

df1 = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data2.csv",encoding="latin1")

df1.head()

df1.tail()

df1.shape

df1.info()

df1.isnull().sum() 

df1.duplicated().sum() # 0 duplicated values

df1.describe()
df1.describe(include=[np.number])

#striping column names
df1.columns = (
    df1.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

categorical_cols = df1.select_dtypes(include='object').columns

#check unique values
for col in categorical_cols:
    print(f"\n{col}")
    print(df1[col].value_counts(dropna=False).head())

#boxplot
df1.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


df1_raw = df1.copy()


df1 = df1.dropna(how='all')
df1 = df1.drop_duplicates()

#renaming column names
df1.columns = (
    df1.columns
    .str.replace('/', '_', regex=False)
)


#type casting
numeric_like_cols = [
    '2pn_no',
    'embryos_formed',
    'no_of_embryos_frozen',
    'remain_set'
]

for col in numeric_like_cols:
    df1[col] = pd.to_numeric(df1[col], errors='coerce')


df1['protocol'] = df1['protocol'].str.lower().str.strip()

df1['male_female_combined'] = (
    df1['male_female_combined']
    .replace({'F': 'Female', 'M': 'Male', 'C': 'Combined'})
)


#missing values

missing_pct = df1.isnull().mean() * 100

drop_cols = missing_pct[missing_pct > 80].index
drop_cols

df1.drop(columns=drop_cols, inplace=True)

#numeric with median

num_cols = df1.select_dtypes(include=np.number).columns

for col in num_cols:
    df1[col].fillna(df1[col].median(), inplace=True)

#categorical with mode

cat_cols = df1.select_dtypes(include='object').columns

for col in cat_cols:
    df1[col].fillna(df1[col].mode()[0], inplace=True)

#outlier treatment

for col in num_cols:
    Q1 = df1[col].quantile(0.25)
    Q3 = df1[col].quantile(0.75)
    IQR = Q3 - Q1

    lower = Q1 - 1.5 * IQR
    upper = Q3 + 1.5 * IQR

    df1[col] = np.where(df1[col] < lower, lower,
                         np.where(df1[col] > upper, upper, df1[col]))

df1.isnull().sum()


df1.isnull().sum().sum()

#feature engneering

df1['age_group'] = pd.cut(
    df1['age'],
    bins=[18, 25, 30, 35, 40, 50],
    labels=['18-25', '26-30', '31-35', '36-40', '40+']
)

df1['ivf_success'] = (df1['clinical_preg'] == 1).astype(int)

#encoding
df1 = pd.get_dummies(df1, columns=['age_group'], drop_first=True)


df1.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data2_cleaned.csv",
    index=False,
    encoding="utf-8-sig"
)


#eda
num_cols = df1.select_dtypes(include=np.number).columns

eda_summary_df1 = pd.DataFrame({
    'Mean': df1[num_cols].mean(),
    'Median': df1[num_cols].median(),
    'Std_Deviation': df1[num_cols].std(),
    'Skewness': df1[num_cols].skew(),
    'Kurtosis':df1[num_cols].kurtosis()
})

eda_summary_df1

#boxplot
sns.boxplot(x='ivf_success', y='age', data=df1)
plt.title('IVF Success vs Age')
plt.show()


sns.histplot(df1['total_oocytes'], kde=True)
plt.title('Total Oocytes Distribution')
plt.show()















