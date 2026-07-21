import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

df2 = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data3.csv",encoding="latin1")

df2.head()

df2.tail()

df2.shape

df2.info()

df2.isnull().sum() 

df2.duplicated().sum() 

df2.describe()
df2.describe(include=[np.number])

#striping column names
df2.columns = (
    df2.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

categorical_cols = df2.select_dtypes(include='object').columns

#check unique values
for col in categorical_cols:
    print(f"\n{col}")
    print(df2[col].value_counts(dropna=False).head())

#boxplot
df2.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


df2_raw = df2.copy()


#typecasting

date_cols = [
    'date_of_first_presentation_for_ivf',
    'date_pregnancy_was_confirmed',
    'date_of_delivery'
]

for col in date_cols:
    if col in df2.columns:
        df2[col] = pd.to_datetime(df2[col], errors='coerce')


numeric_like_cols = [
    'number_of_cycles_before_successful_or_attempt_at_oocyte_retrival'
]

for col in numeric_like_cols:
    if col in df2.columns:
        df2[col] = pd.to_numeric(df2[col], errors='coerce')

#missing values
missing_pct = df2.isnull().mean() * 100
drop_cols = missing_pct[missing_pct > 80].index

drop_cols

df2.drop(columns=drop_cols, inplace=True)

#numeric with median
num_cols = df2.select_dtypes(include=np.number).columns

for col in num_cols:
    df2[col].fillna(df2[col].median(), inplace=True)
    
#date
median_date = df2['date_of_first_presentation_for_ivf'].median()

df2['date_of_first_presentation_for_ivf'].fillna(median_date, inplace=True)


#categorical with mode
cat_cols = df2.select_dtypes(include='object').columns

for col in cat_cols:
    df2[col].fillna(df2[col].mode()[0], inplace=True)


df2['outcome'] = df2['outcome'].str.lower().str.strip()


#feature engneering
df2['ivf_success'] = (df2['outcome'] == 'pregnancy').astype(int)
#age groups
df2['age_group'] = pd.cut(
    df2['age_(in_years)'],
    bins=[0, 18, 25, 30, 35, 40, 50, 100],
    labels=['<18', '18-25', '26-30', '31-35', '36-40', '41-50', '50+']
)


#outlier capping
for col in num_cols:
    Q1 = df2[col].quantile(0.25)
    Q3 = df2[col].quantile(0.75)
    IQR = Q3 - Q1

    lower = Q1 - 1.5 * IQR
    upper = Q3 + 1.5 * IQR

    df2[col] = np.where(df2[col] < lower, lower,
                         np.where(df2[col] > upper, upper, df2[col]))

df2.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data3_cleaned.csv",
    index=False,
    encoding="utf-8-sig"
)

#eda

num_cols = df2.select_dtypes(include=np.number).columns

eda_summary_df2 = pd.DataFrame({
    'Mean': df2[num_cols].mean(),
    'Median': df2[num_cols].median(),
    'Std_Deviation': df2[num_cols].std(),
    'Skewness': df2[num_cols].skew(),
    'Kurtosis':df2[num_cols].kurtosis()
})

eda_summary_df2


#boxplot
sns.boxplot(x='ivf_success', y='age_(in_years)', data=df2)
plt.title('IVF Success vs Age')
plt.show()


df2['ivf_success'].value_counts(normalize=True) * 100



#autoeda
#pip install dtale
import pandas as pd
import dtale
df = pd.read_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports_and_Dashboards_Data3_cleaned.csv",
    encoding="latin1"
)
d = dtale.show(df)
d.open_browser()


















