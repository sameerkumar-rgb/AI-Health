-- HealthAdvisor AI - Supabase Database Setup
-- Run this in: Supabase Dashboard > SQL Editor > New Query

-- 1. Users Profile Table (extends Supabase Auth)
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_login TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE
);

-- 2. Health Records Table
CREATE TABLE IF NOT EXISTS health_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    -- Personal Info
    name TEXT,
    age INTEGER CHECK (age BETWEEN 1 AND 120),
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    pregnancy TEXT DEFAULT 'none',
    ethnicity TEXT DEFAULT 'asian',

    -- Body Metrics
    height_cm REAL,
    weight_kg REAL,
    waist_cm REAL,
    blood_group TEXT,
    bmi REAL,
    bmi_category TEXT,
    ideal_weight_kg REAL,

    -- Medical History
    conditions TEXT[] DEFAULT '{}',
    medications TEXT DEFAULT '',
    allergies TEXT DEFAULT '',

    -- Lifestyle
    activity_level TEXT,
    sleep_hours REAL,
    water_glasses INTEGER,
    diet_type TEXT,
    smoking TEXT DEFAULT 'no',
    alcohol TEXT DEFAULT 'no',
    goals TEXT[] DEFAULT '{}',

    -- Calculated Results
    health_score INTEGER,
    bmr REAL,
    tdee REAL,
    dosha_vata INTEGER,
    dosha_pitta INTEGER,
    dosha_kapha INTEGER,
    dosha_dominant TEXT
);

-- 3. Reports Table
CREATE TABLE IF NOT EXISTS reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
    record_id UUID REFERENCES health_records(id) ON DELETE CASCADE NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    health_score INTEGER,
    bmi REAL,
    bmi_category TEXT,
    risk_level TEXT CHECK (risk_level IN ('low', 'moderate', 'high', 'critical')),
    top_priorities TEXT[] DEFAULT '{}',
    blood_tests TEXT[] DEFAULT '{}',
    dosha TEXT,
    is_printed BOOLEAN DEFAULT FALSE,
    is_shared BOOLEAN DEFAULT FALSE
);

-- 4. Enable Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies - Users can only access their own data
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile" ON profiles
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can view own health records" ON health_records
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own health records" ON health_records
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own health records" ON health_records
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "Users can view own reports" ON reports
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own reports" ON reports
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- 6. Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, name, email)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
        NEW.email
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 7. Indexes for performance
CREATE INDEX IF NOT EXISTS idx_health_records_user ON health_records(user_id);
CREATE INDEX IF NOT EXISTS idx_health_records_date ON health_records(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_user ON reports(user_id);
CREATE INDEX IF NOT EXISTS idx_reports_record ON reports(record_id);
