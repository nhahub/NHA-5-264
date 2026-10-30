"""
Data Exploration & Data Cleaning  (Python / pandas)
----------------------------------------------------
الملف ده بيغطي خطوتين بس: Exploration و Cleaning.
Feature Engineering / EDA / Visualization بتتعمل في SQL Server و Power BI.

الترتيب:
  1) Load      (load_dataset)
  2) Explore   (explore_data)
  3) Clean     (clean_pipeline) -> بتنفذ بالترتيب:
        standardize_column_names -> replace_placeholders -> convert_numeric_strings
        -> fix_data_types -> clean_text_columns -> remove_duplicates
        -> handle_missing_values -> validate_data -> handle_outliers
  4) Save      (save_clean_data)

استخدامه كـ template لأي داتا:
  - غيّر الـ CONFIG اللي تحت بس (من غير ما تلمس الدوال).
  - أسماء الأعمدة في الـ CONFIG ممكن تكتبها زي ما هي في الملف ("Order ID") أو بعد التوحيد (order_id).
"""

import os
import re
import warnings
import numpy as np
import pandas as pd


# =====================================================================
# CONFIG  <-- الحاجة الوحيدة اللي بتغيرها لكل مشروع
# =====================================================================
CONFIG = {
    "path": "C:\KSU\Digital Egypt Pioneers\Technical\Team_Project\AfaqElevators 2.xlsx",                 # مسار الملف (csv / tsv / xlsx / parquet / json). None -> رفع من Colab
    "output_path": "C:\KSU\Digital Egypt Pioneers\Technical\Team_Project\Cleaned_Sheets\Payments.xlsx",
    "sheet_name": "Payments",           # لملفات Excel بس: اسم الشيت ("Sales") أو رقمه (0 = الأول). None = مقبول بس لو الملف فيه شيت واحد

    "lowercase_columns": False,    # True -> order_id (lower + snake_case) | False -> نفس أسماء الأعمدة الأصلية في الملف

    "id_cols": ["PaymentID",
        "PaymentNumber",
        "InvoiceID",
        "CustomerID"],                # أعمدة IDs/Codes اللي مش بتتحسب (بالإضافة للي بيتعرف عليها من الاسم)
    "keep_text_cols": ["PaymentNumber"],         # أعمدة لازم تفضل نص حتى لو شكلها رقم (سجل تجاري / رقم ضريبي / تليفون). مثال: ["TaxNumber", "Phone"]
    "date_cols": ["PaymentDate"],            # None -> اكتشاف تلقائي، أو حددها: ["Order Date", "Ship Date"]
    "dayfirst": False,            # True لو التواريخ dd/mm/yyyy ومش واضح من القيم
    "duplicates_subset": None,    # None -> الصف كله، أو مثال: ["Order ID", "Product ID"]

    # القيم النصية اللي معناها "فاضي" ("N/A", "-", ...):
    #   values: None -> القايمة الافتراضية PLACEHOLDERS اللي تحت | أو قايمتك: ["", "-", "N/A", "لا يوجد"]
    #   cols  : [] -> تقرير بس (مفيش تحويل) | ["City", "Notes"] -> يحولها لـ NaN في الأعمدة دي بس | "all" -> كل الأعمدة النصية
    "placeholders": {"values": None, "cols": []},

    "numeric_strategy": {"strategy": "median", "cols": []},        # strategy: median | mean | drop  |  cols فاضية أو None = مفيش تعديل
    "categorical_strategy": {"strategy": "mode", "cols": []},      # strategy: mode | unknown | drop |  مثال: "cols": ["City", "Segment"]
    "standardize_case": False,            # Title Case للنصوص (خطر على USA / iPhone / CA)

    # الـ report بيتعمل دايمًا على كل الأعمدة الرقمية (من غير IDs وأعمدة الـ 0/1).
    # cap / remove بيتنفذوا على الأعمدة في cols بس. cols فاضية = مفيش أي تعديل.
    "outlier_strategy": {"strategy": "report", "cols": []},      # strategy: report | cap | remove  |  مثال: {"strategy": "cap", "cols": ["Revenue"]}
    "drop_invalid": False,                # True -> يحذف الصفوف اللي مخالفة للـ validation_rules

    # قواعد المنطق الخاصة بداتتك (سيبها {} لو مفيش). كل الأعمدة اختيارية.
    "validation_rules": {
        "positive":     ["PaymentAmountSAR"],         # لازم > 0
        "non_negative": ["PaymentAmountSAR"],                       # لازم >= 0
        "ranges": {"QF_RefundStoredPositive": (0, 1),
            "QF_PaymentUnder1SAR": (0, 1)},   # (min, max) وممكن None
        # "date_order":   [("StartDate", "PlannedEndDate")], # الأول لازم <= التاني
    },
}

# القيم اللي معناها "فاضي" بس متكتوبة كنص. (مقصود إن 'none' و 'unknown' مش هنا لأنهم ممكن يبقوا category حقيقية)
# دي القايمة الافتراضية بس. بتتطبق على الأعمدة اللي إنت محددها في CONFIG["placeholders"]["cols"].
PLACEHOLDERS = ("", "-", "--", "?", "n/a", "na", "#n/a", "null", "nan", "nil", "missing")


# =====================================================================
# 0. Helpers
# =====================================================================
def _norm_name(col_name) -> str:
    return re.sub(r"[^0-9a-z]+", "_", str(col_name).strip().lower()).strip("_")


def is_id_column(col_name) -> bool:
    """العمود ده ID / Code / Postal (مش رقم بيتحسب)؟"""
    name = _norm_name(col_name)
    return bool(re.search(r"(^|_)(id|code|zip)$", name)) or "postal" in name



def is_date_column_name(col_name) -> bool:
    """التعرف على أسماء أعمدة التواريخ الشائعة."""
    name = _norm_name(col_name)
    return bool(
        re.search(
            r"(^|_)(date|datetime|timestamp)($|_)",
            name
        )
        or re.search(r"(date|datetime|timestamp)$", name)
    )



def get_numeric_cols(df: pd.DataFrame) -> list:
    """
    الأعمدة الرقمية الحقيقية: من غير الـ IDs ومن غير أعمدة الـ flags (اللي قيمها 0/1 بس).
    أعمدة الـ flags مش بتتحسب في الـ outliers ولا الإحصائيات الرقمية.
    """
    cols = []
    for c in df.select_dtypes(include=np.number).columns:
        if is_id_column(c):
            continue
        if set(df[c].dropna().unique()) <= {0, 1}:   # عمود 0/1
            continue
        cols.append(c)
    return cols


def get_text_cols(df: pd.DataFrame) -> list:
    return list(df.select_dtypes(include=["object", "string", "category"]).columns)


def _safe_to_datetime(series: pd.Series, dayfirst: bool = False) -> pd.Series:
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return pd.to_datetime(series, errors="coerce", dayfirst=dayfirst)


def _detect_dayfirst(series: pd.Series):
    """
    بيبص على تواريخ بشكل 25/01/2020 ويقرر:
      True  -> اليوم الأول (فيه قيمة أول رقم فيها > 12)
      False -> الشهر الأول (فيه قيمة تاني رقم فيها > 12)
      None  -> غير واضح (كل القيم <= 12) أو شكل تاني.
    """
    s = series.dropna().astype(str).head(20000)
    parts = s.str.extract(r"^\s*(\d{1,2})[/\-.](\d{1,2})[/\-.]\d{2,4}")
    parts = parts.dropna()
    if parts.empty:
        return None
    a, b = parts[0].astype(int), parts[1].astype(int)
    a_big, b_big = (a > 12).any(), (b > 12).any()
    if a_big and not b_big:
        return True
    if b_big and not a_big:
        return False
    return None


# =====================================================================
# 1. Load
# =====================================================================
def _id_dtype(columns, id_cols=None) -> dict:
    ids = {_norm_name(c) for c in (id_cols or [])}
    return {c: str for c in columns if is_id_column(c) or _norm_name(c) in ids}


def list_sheets(path: str) -> list:
    """أسماء الشيتات في ملف Excel (عشان تختار منها في CONFIG['sheet_name'])."""
    with pd.ExcelFile(path) as xls:
        return xls.sheet_names


def _resolve_sheet(sheets: list, sheet_name):
    """بيحول اسم/رقم الشيت لاسم شيت حقيقي، أو يرمي error واضح فيه الشيتات المتاحة."""
    listing = "\n".join(f"   [{i}] {name}" for i, name in enumerate(sheets))
    if sheet_name is None:
        if len(sheets) == 1:
            return sheets[0]
        raise ValueError(f"الملف فيه {len(sheets)} شيتات، لازم تحدد واحد في CONFIG['sheet_name'] "
                         f"(بالاسم أو برقمه):\n{listing}")
    if isinstance(sheet_name, int):
        if 0 <= sheet_name < len(sheets):
            return sheets[sheet_name]
        raise ValueError(f"رقم الشيت {sheet_name} خارج النطاق. الشيتات المتاحة:\n{listing}")
    if sheet_name in sheets:
        return sheet_name
    loose = [n for n in sheets if str(n).strip().lower() == str(sheet_name).strip().lower()]
    if len(loose) == 1:  # فرق في المسافات أو حالة الحروف بس
        return loose[0]
    raise ValueError(f"الشيت '{sheet_name}' مش موجود. الشيتات المتاحة:\n{listing}")


def load_dataset(path: str, id_cols: list = None, sheet_name=None,
                 encodings: tuple = ("utf-8", "latin1"), **read_kwargs) -> pd.DataFrame:
    """
    بيقرا csv / tsv / xlsx / xls / parquet / json.
    - أعمدة الـ IDs (من الاسم أو من id_cols) بتتقرا كنص عشان الصفر اللي في الأول مايضيعش.
      (run_from_config بيبعت هنا كمان keep_text_cols، فبتتقرا كنص برضه.)
    - Excel فيه كذا شيت: حدد sheet_name (اسم أو رقم). لو مش محدد والملف فيه أكتر من شيت
      بيرمي error فيه قايمة الشيتات بدل ما يختار واحد لوحده.
    - لو فشل بيرمي error واضح بدل ما يرجع None.
    - read_kwargs بتتبعت لـ pandas (مثال: sheet_name="Sheet2" أو sep=";").
    """
    ext = os.path.splitext(str(path))[1].lower()

    if ext in (".xlsx", ".xlsm", ".xls"):
        with pd.ExcelFile(path) as xls:
            sheet = _resolve_sheet(xls.sheet_names, sheet_name)
            header = xls.parse(sheet, nrows=0, **read_kwargs)
            df = xls.parse(sheet, dtype=_id_dtype(header.columns, id_cols), **read_kwargs)
        print(f"تم قراءة الشيت '{sheet}' بنجاح ({df.shape[0]} صف × {df.shape[1]} عمود)")
        return df
    if sheet_name is not None:
        print("تنبيه: sheet_name بيتجاهل لأن الملف مش Excel")
    if ext == ".parquet":
        print("تم قراءة ملف parquet بنجاح")
        return pd.read_parquet(path, **read_kwargs)
    if ext == ".json":
        print("تم قراءة ملف json بنجاح")
        return pd.read_json(path, **read_kwargs)

    sep = "\t" if ext == ".tsv" else read_kwargs.pop("sep", ",")
    last_err = None
    for enc in encodings:
        try:
            header = pd.read_csv(path, nrows=0, encoding=enc, sep=sep)
            dtype = _id_dtype(header.columns, id_cols)
            df = pd.read_csv(path, encoding=enc, sep=sep, dtype=dtype, low_memory=False, **read_kwargs)
            print(f"تم قراءة البيانات بنجاح (encoding = {enc})")
            return df
        except UnicodeDecodeError as e:
            print(f"Failed to load with {enc}, trying the next one...")
            last_err = e
    raise last_err


# =====================================================================
# 2. Data Exploration  (قراءة فقط، مابتغيرش في الداتا)
# =====================================================================
def missing_report(df: pd.DataFrame) -> pd.DataFrame:
    report = pd.DataFrame({
        "Missing Count": df.isnull().sum(),
        "%": (df.isnull().sum() / len(df) * 100).round(2),
    })
    return report.sort_values("Missing Count", ascending=False)


def find_case_variants(df: pd.DataFrame) -> pd.DataFrame:
    """أعمدة نصية فيها نفس القيمة مكتوبة بأشكال مختلفة (east / EAST / 'East ')."""
    rows = []
    for col in get_text_cols(df):
        u = pd.Series(df[col].dropna().astype(str).unique())
        n_raw = len(u)
        n_norm = u.str.strip().str.lower().str.replace(r"\s+", " ", regex=True).nunique()
        if n_norm < n_raw:
            rows.append({"column": col, "distinct_raw": n_raw, "distinct_after_normalizing": n_norm})
    return pd.DataFrame(rows)


def explore_data(df: pd.DataFrame, max_unique_for_value_counts: int = 15) -> None:
    line = "=" * 60

    print(line, "\n1) Shape & memory\n", line)
    print(df.shape, f"| memory: {df.memory_usage(deep=True).sum() / 1e6:.1f} MB")

    print(line, "\n2) Column names\n", line)
    print(list(df.columns))

    print(line, "\n3) First 5 rows\n", line)
    print(df.head())

    print(line, "\n4) Info & Data types\n", line)
    df.info()

    print(line, "\n5) Missing values\n", line)
    print(missing_report(df))
    high = missing_report(df).query("`%` > 50").index.tolist()
    if high:
        print(f"تنبيه: أعمدة أكتر من 50% منها فاضي: {high}")

    print(line, "\n6) Duplicates (full row)\n", line)
    print(f"Number of fully duplicated rows: {df.duplicated().sum()}")

    print(line, "\n7) Unique values per column (nunique)\n", line)
    nun = df.nunique().sort_values()
    print(nun)
    const = nun[nun <= 1].index.tolist()
    if const:
        print(f"تنبيه: أعمدة قيمتها ثابتة (ملهاش فايدة في التحليل): {const}")

    print(line, "\n8) Numeric summary (describe)\n", line)
    num_df = df.select_dtypes(include=np.number)
    if not num_df.empty:
        print(num_df.describe().T)

    print(line, "\n9) Text summary (describe)\n", line)
    txt_df = df.select_dtypes(include=["object", "string", "category"])
    if not txt_df.empty:
        print(txt_df.describe().T)

    print(line, "\n10) Value counts for low-cardinality text columns\n", line)
    for col in get_text_cols(df):
        if df[col].nunique() <= max_unique_for_value_counts:
            print(f"\n--- {col} ---")
            print(df[col].value_counts(dropna=False))

    print(line, "\n11) Same value written differently (case / spaces)\n", line)
    variants = find_case_variants(df)
    print(variants if not variants.empty else "لا يوجد")

    print(line, "\n12) Columns with mixed Python types (on a sample)\n", line)
    mixed = []
    for col in df.select_dtypes(include=["object", "str"]).columns:
        sample = df[col].dropna().head(100000)
        if sample.map(type).nunique() > 1:
            mixed.append(col)
    print(mixed if mixed else "لا يوجد")

    print(line, "\n13) Date range\n", line)
    for col in df.columns:
        if is_date_column_name(col):
            parsed = _safe_to_datetime(df[col])
            bad = parsed.isna().sum() - df[col].isna().sum()
            print(f"{col}: {parsed.min()}  ->  {parsed.max()}  (unparseable: {bad})")
            if parsed.notna().any() and not pd.api.types.is_datetime64_any_dtype(df[col]):
                if _detect_dayfirst(df[col]) is None and df[col].astype(str).str.contains(r"[/\-.]").any():
                    print(f"   تنبيه: شكل التاريخ في '{col}' ممكن يتفهم dd/mm أو mm/dd، راجعه.")

    print(line, "\n14) Skewness & correlation (numeric columns)\n", line)
    real_num = df[get_numeric_cols(df)]
    if not real_num.empty:
        print(real_num.skew().round(2))
        if real_num.shape[1] <= 15:
            print(real_num.corr().round(2))


# =====================================================================
# 3. Data Cleaning
# =====================================================================
def standardize_column_names(df: pd.DataFrame) -> pd.DataFrame:
    """'Order Date' -> 'order_date'."""
    df = df.copy()
    df.columns = [_norm_name(c) for c in df.columns]
    if df.columns.duplicated().any():
        dup = df.columns[df.columns.duplicated()].tolist()
        raise ValueError(f"أسماء أعمدة مكررة بعد التوحيد: {dup}")
    return df


def replace_placeholders(df: pd.DataFrame, placeholders: tuple = PLACEHOLDERS, cols=None) -> pd.DataFrame:
    """
    تحويل القيم النصية اللي معناها 'فاضي' ('-', '?', 'N/A', ...) لـ NaN حقيقي.
    cols = قايمة الأعمدة اللي يتحول فيها (أو "all" لكل الأعمدة النصية).
    الأعمدة اللي مش في cols مابتتغيرش، بس بيتطبع تقرير بعدد القيم اللي شكلها placeholder فيها.
    """
    df = df.copy()
    ph = [str(p).strip().lower() for p in placeholders]
    text_cols = get_text_cols(df)
    target = set(text_cols) if cols == "all" else set(cols or [])

    for col in sorted(target - set(text_cols)):
        print(f"'{col}': مش عمود نصي، اتجاهل (placeholders)")

    for col in text_cols:
        s = df[col].astype("object")
        norm = s.astype("string").str.strip().str.lower()
        mask = norm.isin(ph).fillna(False).astype(bool).to_numpy()
        n = int(mask.sum())
        if not n:
            continue
        if col in target:
            df[col] = s.mask(mask, np.nan)
            print(f"'{col}': {n} قيمة placeholder اتحولت لـ NaN")
        else:
            print(f"'{col}': فيه {n} قيمة شكلها placeholder (ماتغيرتش). "
                  f"ضيف العمود في placeholders.cols لو عايز تحولها لـ NaN")
    return df


def convert_numeric_strings(df: pd.DataFrame, min_parse_rate: float = 0.99,
                            skip_cols: list = None) -> pd.DataFrame:
    """
    أعمدة أرقام متخزنة كنص ("$1,200", " 45 ") -> رقم.
    بتتجاهل: الـ IDs، التواريخ، الأعمدة اللي فيها صفر في الأول (زي أرقام التليفون)،
    والأعمدة اللي فيها فاصلة عشرية أوروبية (1,5) لأن تحويلها ممكن يبقى غلط،
    وأي عمود في skip_cols (id_cols + keep_text_cols).
    ومابتحولش العمود إلا لو >= min_parse_rate من قيمه اتحولت.
    """
    df = df.copy()
    for col in df.select_dtypes(include=["object", "string"]).columns:
        if is_id_column(col) or is_date_column_name(col) or col in (skip_cols or []):
            continue
        s = df[col].dropna().astype(str).str.strip()
        if s.empty or s.str.match(r"^0\d+").any():
            continue
        if s.str.contains(r"\d,\d{1,2}$").any():
            print(f"'{col}': شكل الأرقام فيه فاصلة ممكن تكون عشرية، اتجاهل (راجعه بإيدك)")
            continue
        cleaned = s.str.replace(r"[,$€£\s]", "", regex=True)
        if pd.to_numeric(cleaned, errors="coerce").notna().mean() < min_parse_rate:
            continue
        full = df[col].astype("string").str.strip().str.replace(r"[,$€£\s]", "", regex=True)
        converted = pd.to_numeric(full, errors="coerce").astype("float64")
        newly_bad = int(converted.isna().sum() - df[col].isna().sum())
        if converted.notna().all() and (converted % 1 == 0).all():
            converted = converted.astype("int64")
        df[col] = converted
        print(f"'{col}': اتحول من نص لرقم" + (f" ({newly_bad} قيمة مابقتش رقم وبقت NaN)" if newly_bad else ""))
    return df


def fix_data_types(df: pd.DataFrame, date_cols: list = None, id_cols: list = None,
                   dayfirst: bool = False, min_date_parse_rate: float = 0.8) -> pd.DataFrame:
    """
    - date_cols -> datetime. لو مش متحددة بيدور على أعمدة اسمها فيه date كـ كلمة كاملة،
      وما بيحولش العمود إلا لو >= min_date_parse_rate من قيمه تاريخ فعلًا.
    - لو التواريخ شكلها dd/mm/yyyy وواضح من القيم (يوم > 12) بيستخدم dayfirst=True تلقائي.
    - id_cols -> string (لو مش متحددة بيدور على أعمدة ID / Code / Postal).
    """
    df = df.copy()
    auto_dates = date_cols is None
    if auto_dates:
        date_cols = [c for c in df.columns if is_date_column_name(c)]
    if id_cols is None:
        id_cols = [c for c in df.columns if is_id_column(c)]

    for col in date_cols:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            continue
        if auto_dates and pd.api.types.is_numeric_dtype(df[col]):
            print(f"'{col}': رقمي، اتجاهل (حدده في date_cols لو عايز تحوله)")
            continue
        col_dayfirst = dayfirst
        detected = _detect_dayfirst(df[col])
        if detected is not None and detected != dayfirst:
            col_dayfirst = detected
            print(f"'{col}': اتضح من القيم إن الشكل {'dd/mm/yyyy' if detected else 'mm/dd/yyyy'}، هستخدمه")
        parsed = _safe_to_datetime(df[col], col_dayfirst)
        non_null = int(df[col].notna().sum())
        rate = parsed.notna().sum() / non_null if non_null else 0
        if auto_dates and rate < min_date_parse_rate:
            print(f"'{col}': مش شكله تاريخ ({rate:.0%} بس اتحولوا)، اتجاهل")
            continue
        new_na = int(parsed.isna().sum() - df[col].isna().sum())
        if new_na > 0:
            print(f"تحذير: {new_na} قيمة في '{col}' ماقدرتش تتحول لتاريخ (بقت NaT)")
        df[col] = parsed

    for col in id_cols:
        if pd.api.types.is_numeric_dtype(df[col]):
            try:  # 12345.0 -> '12345'
                df[col] = df[col].astype("Int64").astype("string").astype("object")
                continue
            except (TypeError, ValueError):
                pass
        df[col] = df[col].astype("string").astype("object")
    return df


def clean_text_columns(df: pd.DataFrame, standardize_case: bool = False,
                       title_case_max_unique: int = 50, skip_cols: list = None) -> pd.DataFrame:
    """
    - دايمًا: شيل المسافات من الأول والآخر + المسافات المتكررة جوه النص.
    - standardize_case=True: Title Case للأعمدة قليلة القيم (مش IDs).
      مقفولة افتراضيًا لأنها بتبوّظ قيم زي USA -> Usa و iPhone -> Iphone و CA -> Ca.
      استخدمها بس لو explore_data بلغتك إن فيه قيم مكررة بحالات حروف مختلفة.
    """
    df = df.copy()
    for col in get_text_cols(df):
        df[col] = df[col].astype("object")
        mask = df[col].notna()
        df.loc[mask, col] = (
            df.loc[mask, col].astype(str).str.strip().str.replace(r"\s+", " ", regex=True)
        )
        if (standardize_case and not is_id_column(col) and col not in (skip_cols or [])
                and df[col].nunique() <= title_case_max_unique):
            df.loc[mask, col] = df.loc[mask, col].str.title()
    return df


def remove_duplicates(df: pd.DataFrame, subset: list = None) -> pd.DataFrame:
    """
    subset=None  -> الصف كله لازم يتكرر.
    subset=[...] -> تكرار على أعمدة معينة (مثال: ['order_id', 'product_id']).
    انتبه: في داتا معاملات، صفوف متطابقة ممكن تبقى معاملات حقيقية متكررة.
    """
    before = len(df)
    cleaned = df.drop_duplicates(subset=subset, keep="first").reset_index(drop=True)
    print(f"تم إزالة {before - len(cleaned)} صف مكرر")
    return cleaned


def handle_missing_values(df: pd.DataFrame, numeric_strategy: str = None, numeric_cols: list = None,
                          categorical_strategy: str = None, categorical_cols: list = None,
                          skip_cols: list = None) -> pd.DataFrame:
    """
    بتعالج الأعمدة اللي إنت محددها بس. لو مفيش أعمدة = مفيش أي تعديل.
    numeric_strategy     : 'median' | 'mean' | 'drop'
    categorical_strategy : 'mode'   | 'unknown' | 'drop'
    """
    df = df.copy()
    drop_subset = []
    skip = set(skip_cols or [])

    for col in (numeric_cols or []):
        if col in skip or is_id_column(col):
            print(f"'{col}': عمود ID، اتجاهل")
            continue
        if not pd.api.types.is_numeric_dtype(df[col]):
            print(f"'{col}': مش رقمي، اتجاهل")
            continue
        n = int(df[col].isnull().sum())
        if n == 0:
            continue
        if numeric_strategy == "drop":
            drop_subset.append(col)
            continue
        value = df[col].mean() if numeric_strategy == "mean" else df[col].median()
        if pd.isna(value):
            print(f"'{col}': كله فاضي، اتجاهل")
            continue
        df[col] = df[col].fillna(value)
        print(f"'{col}': {n} قيمة اتملت بـ {numeric_strategy} ({value})")

    for col in (categorical_cols or []):
        if col in skip or is_id_column(col):
            print(f"'{col}': عمود ID، اتجاهل")
            continue
        if col not in get_text_cols(df):
            print(f"'{col}': مش نصي، اتجاهل")
            continue
        n = int(df[col].isnull().sum())
        if n == 0:
            continue
        if categorical_strategy == "drop":
            drop_subset.append(col)
            continue
        if categorical_strategy == "mode":
            modes = df[col].mode()
            fill = modes.iloc[0] if len(modes) > 0 else "Unknown"
        else:
            fill = "Unknown"
        df[col] = df[col].fillna(fill)
        print(f"'{col}': {n} قيمة اتملت بـ '{fill}'")

    if drop_subset:
        before = len(df)
        df = df.dropna(subset=drop_subset).reset_index(drop=True)
        print(f"تم حذف {before - len(df)} صف فيه missing")

    remaining = df.isnull().sum()
    remaining = remaining[remaining > 0]
    if remaining.empty:
        print("مفيش missing values متبقية")
    else:
        print("لسه فيه missing في:")
        print(remaining)
    return df


def validate_data(df: pd.DataFrame, rules: dict = None, drop_invalid: bool = False) -> pd.DataFrame:
    """
    فحوصات منطقية حسب rules اللي إنت بتحددها (مفيش حاجة مفترضة عن داتتك):
        {
          "positive":     ["sales", "quantity"],            # لازم > 0
          "non_negative": ["age"],                          # لازم >= 0
          "ranges":       {"discount": (0, 1), "age": (0, 120)},   # (min, max)، وممكن None
          "date_order":   [("order_date", "ship_date")],    # الأول لازم <= التاني
        }
    - لو عمود في الـ rules مش موجود بيطبعلك تحذير (مش بيتخطاه بصمت).
    - drop_invalid=False -> تقرير بس | True -> يحذف الصفوف المخالفة.
    """
    df = df.copy()
    if not rules:
        print("Validation: مفيش rules متحددة (validation_rules)، اتخطّى الخطوة دي.")
        return df

    checks = {}

    def usable(col, kind):
        col = _norm_name(col)
        if col not in df.columns:
            print(f"تحذير (validation): العمود '{col}' مش موجود")
            return None
        ok = (pd.api.types.is_datetime64_any_dtype(df[col]) if kind == "date"
              else pd.api.types.is_numeric_dtype(df[col]))
        if not ok:
            print(f"تحذير (validation): العمود '{col}' مش من النوع المناسب ({kind})")
            return None
        return col

    for raw in rules.get("positive", []):
        col = usable(raw, "numeric")
        if col:
            checks[f"{col} <= 0"] = df[col] <= 0
    for raw in rules.get("non_negative", []):
        col = usable(raw, "numeric")
        if col:
            checks[f"{col} < 0"] = df[col] < 0
    for raw, (lo, hi) in rules.get("ranges", {}).items():
        col = usable(raw, "numeric")
        if col:
            m = pd.Series(False, index=df.index)
            if lo is not None:
                m |= df[col] < lo
            if hi is not None:
                m |= df[col] > hi
            checks[f"{col} outside [{lo}, {hi}]"] = m
    for first, second in rules.get("date_order", []):
        a, b = usable(first, "date"), usable(second, "date")
        if a and b:
            checks[f"{b} before {a}"] = df[b] < df[a]

    if not checks:
        print("Validation: مفيش فحوصات اتنفذت (راجع أسماء الأعمدة في الـ rules)")
        return df

    invalid_mask = pd.Series(False, index=df.index)
    print("Validation report:")
    for name, mask in checks.items():
        mask = mask.fillna(False)
        print(f"  - {name}: {int(mask.sum())} rows")
        invalid_mask |= mask

    if drop_invalid and invalid_mask.any():
        df = df[~invalid_mask].reset_index(drop=True)
        print(f"تم حذف {int(invalid_mask.sum())} صف غير منطقي")
    return df


def detect_outliers_iqr(df: pd.DataFrame, factor: float = 1.5) -> pd.DataFrame:
    rows = []
    for col in get_numeric_cols(df):
        q1, q3 = df[col].quantile([0.25, 0.75])
        iqr = q3 - q1
        lower, upper = q1 - factor * iqr, q3 + factor * iqr
        n_out = int(((df[col] < lower) | (df[col] > upper)).sum())
        rows.append({"column": col, "lower_bound": round(lower, 2), "upper_bound": round(upper, 2),
                     "outliers": n_out, "%": round(n_out / len(df) * 100, 2)})
    return pd.DataFrame(rows)


def handle_outliers(df: pd.DataFrame, strategy: str = "report", cols: list = None,
                    factor: float = 1.5) -> pd.DataFrame:
    """
    الـ report بيتطبع دايمًا على كل الأعمدة الرقمية (من غير IDs وأعمدة الـ 0/1).
    'report' -> تقرير بس (الافتراضي، لأن كتير من الـ outliers قيم حقيقية)
    'cap'    -> قص القيم على الحدود، في الأعمدة اللي في cols بس
    'remove' -> حذف أي صف فيه outlier في أي عمود من cols (عنيف: ممكن يشيل نسبة كبيرة)
    cols فاضية مع cap / remove = مفيش أي تعديل.
    """
    df = df.copy()
    print("Outliers report (IQR):")
    print(detect_outliers_iqr(df, factor))
    if strategy == "report":
        return df

    if not cols:
        print(f"Outliers: strategy='{strategy}' بس مفيش أعمدة متحددة في outlier_strategy['cols']، مفيش أي تعديل.")
        return df

    allowed = set(get_numeric_cols(df))
    target = []
    for col in cols:
        if col in allowed:
            target.append(col)
        else:
            print(f"'{col}': مش عمود رقمي حقيقي (ID أو 0/1 flag أو مش رقمي)، اتجاهل")

    keep_mask = pd.Series(True, index=df.index)
    for col in target:
        q1, q3 = df[col].quantile([0.25, 0.75])
        iqr = q3 - q1
        lower, upper = q1 - factor * iqr, q3 + factor * iqr
        if strategy == "cap":
            n_cap = int(((df[col] < lower) | (df[col] > upper)).sum())
            df[col] = df[col].clip(lower, upper)
            print(f"'{col}': {n_cap} قيمة اتقصت على [{round(lower, 2)}, {round(upper, 2)}]")
        elif strategy == "remove":
            keep_mask &= df[col].between(lower, upper) | df[col].isna()
    if strategy == "remove":
        before = len(df)
        df = df[keep_mask].reset_index(drop=True)
        print(f"تم حذف {before - len(df)} صف فيه outliers")
    return df


# =====================================================================
# 4. Pipeline + Save
# =====================================================================
def _norm_list(cols):
    return None if cols is None else [_norm_name(c) for c in cols]


def _parse_missing_cfg(cfg, label, valid):
    """{'strategy': 'median', 'cols': [...]} -> (strategy, cols_موحدة). None أو cols فاضية -> مفيش تعديل."""
    if not cfg:
        return None, []
    if not isinstance(cfg, dict):
        raise TypeError(f"{label} لازم dict بالشكل {{'strategy': ..., 'cols': [...]}}")
    cols = cfg.get("cols")
    if isinstance(cols, str):
        cols = [cols]
    cols = _norm_list(cols) or []
    if not cols:
        return None, []
    strategy = cfg.get("strategy")
    if strategy not in valid:
        raise ValueError(f"{label}: strategy لازم تكون واحدة من {valid}، مش {strategy!r}")
    return strategy, cols


def _parse_outlier_cfg(cfg):
    """
    {'strategy': 'report'|'cap'|'remove', 'cols': [...]} -> (strategy, cols_موحدة).
    بتقبل كمان string لوحده ("report") للتوافق مع الشكل القديم.
    """
    valid = ("report", "cap", "remove")
    if not cfg:
        return "report", []
    if isinstance(cfg, str):
        cfg = {"strategy": cfg, "cols": []}
    if not isinstance(cfg, dict):
        raise TypeError("outlier_strategy لازم dict بالشكل {'strategy': ..., 'cols': [...]}")
    strategy = cfg.get("strategy", "report")
    if strategy not in valid:
        raise ValueError(f"outlier_strategy: strategy لازم تكون واحدة من {valid}، مش {strategy!r}")
    cols = cfg.get("cols")
    if isinstance(cols, str):
        cols = [cols]
    return strategy, _norm_list(cols) or []


def _parse_placeholders_cfg(cfg):
    """
    {'values': [...] | None, 'cols': [...] | 'all'} -> (values, cols).
    values=None -> القايمة الافتراضية PLACEHOLDERS | cols فاضية -> مفيش تحويل (تقرير بس).
    """
    if not cfg:
        return PLACEHOLDERS, []
    if not isinstance(cfg, dict):
        raise TypeError("placeholders لازم dict بالشكل {'values': [...], 'cols': [...]}")
    values = cfg.get("values")
    values = PLACEHOLDERS if values is None else tuple(str(v).strip().lower() for v in values)
    cols = cfg.get("cols")
    if isinstance(cols, str):
        if cols.strip().lower() == "all":
            return values, "all"
        cols = [cols]
    return values, _norm_list(cols) or []


def clean_pipeline(df_raw: pd.DataFrame,
                   id_cols: list = None,
                   keep_text_cols: list = None,
                   date_cols: list = None,
                   duplicates_subset: list = None,
                   numeric_strategy: dict = None,
                   categorical_strategy: dict = None,
                   standardize_case: bool = False,
                   dayfirst: bool = False,
                   validation_rules: dict = None,
                   drop_invalid: bool = False,
                   outlier_strategy: dict = None,
                   lowercase_columns: bool = True,
                   placeholders: dict = None) -> pd.DataFrame:
    """
    بتنفذ كل خطوات الـ cleaning بالترتيب وبترجع نسخة جديدة (الأصل مايتغيرش).
    أسماء الأعمدة (id_cols / date_cols / duplicates_subset / ...) ممكن تكتبها بالشكل الأصلي ("Order ID").
    لو كتبت اسم عمود غلط بيرمي error فورًا بدل ما يتجاهله.
    """
    id_given = _norm_list(id_cols) or []
    keep_text = _norm_list(keep_text_cols) or []
    date_given = _norm_list(date_cols)
    subset = _norm_list(duplicates_subset)

    num_strategy, num_cols = _parse_missing_cfg(numeric_strategy, "numeric_strategy", ("median", "mean", "drop"))
    cat_strategy, cat_cols = _parse_missing_cfg(categorical_strategy, "categorical_strategy", ("mode", "unknown", "drop"))
    out_strategy, out_cols = _parse_outlier_cfg(outlier_strategy)
    ph_values, ph_cols = _parse_placeholders_cfg(placeholders)

    df = standardize_column_names(df_raw)
    name_map = dict(zip(df.columns, df_raw.columns))   # الاسم الموحد -> الاسم الأصلي
    for label, cols in (("id_cols", id_given), ("keep_text_cols", keep_text),
                        ("date_cols", date_given or []),
                        ("duplicates_subset", subset or []), ("numeric_strategy.cols", num_cols),
                        ("categorical_strategy.cols", cat_cols), ("outlier_strategy.cols", out_cols),
                        ("placeholders.cols", [] if ph_cols == "all" else ph_cols)):
        missing = [c for c in cols if c not in df.columns]
        if missing:
            raise KeyError(f"{label}: أعمدة مش موجودة {missing} | الأعمدة المتاحة: {list(df.columns)}")

    protected = id_given + keep_text   # أعمدة مابتتحولش لأرقام ومابيتعملهاش Title Case

    df = replace_placeholders(df, ph_values, ph_cols)
    df = convert_numeric_strings(df, skip_cols=protected)
    ids = [c for c in df.columns if is_id_column(c) or c in id_given]
    df = fix_data_types(df, date_cols=date_given, id_cols=ids, dayfirst=dayfirst)
    df = clean_text_columns(df, standardize_case=standardize_case, skip_cols=protected)
    df = remove_duplicates(df, subset=subset)
    df = handle_missing_values(df, num_strategy, num_cols, cat_strategy, cat_cols, skip_cols=id_given)
    df = validate_data(df, rules=validation_rules, drop_invalid=drop_invalid)
    df = handle_outliers(df, strategy=out_strategy, cols=out_cols)
    if not lowercase_columns:
        df = df.rename(columns=name_map)
    print(f"\nShape before: {df_raw.shape}  ->  after: {df.shape}")
    return df


def run_from_config(config: dict, df_raw: pd.DataFrame = None) -> pd.DataFrame:
    """بيشغل Load -> Explore -> Clean -> Save باستخدام الـ CONFIG."""
    if df_raw is None:
        # الـ IDs و keep_text_cols بيتقرأوا كنص من الأول عشان الأصفار اللي في الأول مايضيعوش
        df_raw = load_dataset(config["path"],
                              id_cols=(config.get("id_cols") or []) + (config.get("keep_text_cols") or []),
                              sheet_name=config.get("sheet_name"))
    explore_data(df_raw)
    df_clean = clean_pipeline(
        df_raw,
        id_cols=config.get("id_cols"),
        keep_text_cols=config.get("keep_text_cols"),
        date_cols=config.get("date_cols"),
        duplicates_subset=config.get("duplicates_subset"),
        numeric_strategy=config.get("numeric_strategy"),
        categorical_strategy=config.get("categorical_strategy"),
        standardize_case=config.get("standardize_case", False),
        dayfirst=config.get("dayfirst", False),
        validation_rules=config.get("validation_rules"),
        drop_invalid=config.get("drop_invalid", False),
        outlier_strategy=config.get("outlier_strategy"),
        lowercase_columns=config.get("lowercase_columns", True),
        placeholders=config.get("placeholders"),
    )
    return df_clean



def save_clean_data(df: pd.DataFrame, path: str = "clean_data.csv") -> None:
    ext = os.path.splitext(path)[1].lower()

    if ext == ".parquet":
        df.to_parquet(path, index=False)

    elif ext == ".xlsx":
        df.to_excel(path, index=False, engine="openpyxl")

    elif ext == ".csv":
        df.to_csv(path, index=False, encoding="utf-8-sig")

    else:
        raise ValueError(
            f"صيغة الملف غير مدعومة: {ext}. "
            "استخدم .csv أو .xlsx أو .parquet"
        )

    print(f"تم حفظ الداتا النضيفة في: {path}")


# =====================================================================
# 5. Run
# =====================================================================
if __name__ == "__main__":
    # للداتا الكبيرة في Colab: ماتستخدمش files.upload(). اعمل mount لـ Drive وحط المسار في CONFIG["path"]:
    #   from google.colab import drive; drive.mount('/content/drive')
    colab_files = None
    if CONFIG["path"] is None:
        try:
            from google.colab import files as colab_files
            uploaded = colab_files.upload()
            CONFIG["path"] = list(uploaded.keys())[0]
            print(f"تم رفع البيانات بنجاح: {CONFIG['path']}")
        except ImportError:
            raise SystemExit("حط مسار الملف في CONFIG['path'] (مش شغال على Colab).")

    df_clean = run_from_config(CONFIG)
    save_clean_data(df_clean, CONFIG["output_path"])
    if colab_files is not None:
        colab_files.download(CONFIG["output_path"])

# Compine All Excel Files into Only one Excel file that Contains Multiple Sheets
"""
import pandas as pd
from pathlib import Path

# Folder containing all the Excel files
input_folder = Path(
    r"C:\KSU\Digital Egypt Pioneers\Technical\Team_Project\Cleaned_Sheets"
)

# Output workbook
output_file = input_folder / "AfaqElevators_Cleaned.xlsx"

# Get all Excel files in the folder, excluding the output file
excel_files = [
    file for file in input_folder.glob("*.xlsx")
    if file.name != output_file.name
    and not file.name.startswith("~$")
]

# Write each Excel file to a separate worksheet
with pd.ExcelWriter(output_file, engine="openpyxl") as writer:
    for file in excel_files:
        df = pd.read_excel(file)

        # Use the file name as the worksheet name
        sheet_name = file.stem[:31]

        df.to_excel(
            writer,
            sheet_name=sheet_name,
            index=False
        )

print(f"Combined workbook saved to: {output_file}")
print(f"Number of worksheets: {len(excel_files)}")
"""