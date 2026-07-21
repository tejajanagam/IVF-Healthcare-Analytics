import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns

c = pd.read_csv(r"C:\Users\tejaj\OneDrive\Desktop\project 2\Reports and Dashboards Data1c.csv",encoding="latin1")

c.head()

c.tail()

c.shape

c.info()

c.isnull().sum() 

c.duplicated().sum() 

c.describe()
c.describe(include=[np.number])

#striping column names
c.columns = (
    c.columns
    .str.lower()
    .str.strip()
    .str.replace(' ', '_')
    .str.replace('%', 'percent')
    .str.replace('-', '_')
    .str.replace('\n', '')
)

c.columns = (
    c.columns
    .str.replace('(', '', regex=False)
    .str.replace(')', '', regex=False)
    .str.replace('/', '_', regex=False)
    .str.replace(':', '', regex=False)
)


c.columns.tolist()


#boxplot
c.select_dtypes(include=np.number).boxplot(figsize=(15,6))
plt.xticks(rotation=90)
plt.show()


c_raw = c.copy()

c.drop(columns=['unnamed_3'], inplace=True)



c['group_label'] = c['group1=chm_2=non_chm'].map({
    1: 'CHM',
    2: 'Non-CHM'
})


c.to_csv(
    r"C:\Users\tejaj\OneDrive\Desktop\project 2\Data1c_cleaned.csv",
    index=False,
    encoding='utf-8-sig'
)

#eda
num_cols = c.select_dtypes(include=np.number).columns

eda_summary_c = pd.DataFrame({
    'Mean': c[num_cols].mean(),
    'Median': c[num_cols].median(),
    'Std_Deviation': c[num_cols].std(),
    'Skewness': c[num_cols].skew(),
    'Kurtosis': c[num_cols].kurtosis()
})

eda_summary_c


#boxplot
sns.boxplot(x='group1=chm_2=non_chm', y='bmp15pg_ml', data=c)
plt.title('BMP15 Levels: CHM vs Non-CHM')
plt.show()































