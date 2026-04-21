-- ============================================
-- HealthAdvisor AI - SQL Structure Fix
-- Patches all 11 gaps identified in review
-- Run in: Supabase Dashboard > SQL Editor
-- ============================================

-- ─────────────────────────────────────────────
-- GAP 1: Add updated_at columns
-- ─────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE health_records ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE reports ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Auto-update updated_at on row change
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_profiles_updated ON profiles;
CREATE TRIGGER trg_profiles_updated
    BEFORE UPDATE ON profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_health_records_updated ON health_records;
CREATE TRIGGER trg_health_records_updated
    BEFORE UPDATE ON health_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_reports_updated ON reports;
CREATE TRIGGER trg_reports_updated
    BEFORE UPDATE ON reports
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ─────────────────────────────────────────────
-- GAP 2: Soft delete support
-- ─────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE health_records ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;
ALTER TABLE reports ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ DEFAULT NULL;

-- ─────────────────────────────────────────────
-- GAP 3: Field constraints & validations
-- ─────────────────────────────────────────────
DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_height
        CHECK (height_cm IS NULL OR height_cm BETWEEN 50 AND 250);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_weight
        CHECK (weight_kg IS NULL OR weight_kg BETWEEN 10 AND 300);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_waist
        CHECK (waist_cm IS NULL OR waist_cm BETWEEN 30 AND 200);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_sleep
        CHECK (sleep_hours IS NULL OR sleep_hours BETWEEN 1 AND 16);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_water
        CHECK (water_glasses IS NULL OR water_glasses BETWEEN 0 AND 30);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_health_score
        CHECK (health_score IS NULL OR health_score BETWEEN 10 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_bmi
        CHECK (bmi IS NULL OR bmi BETWEEN 10 AND 60);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_activity_level
        CHECK (activity_level IS NULL OR activity_level IN ('sedentary', 'light', 'moderate', 'active', 'athlete'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_diet_type
        CHECK (diet_type IS NULL OR diet_type IN ('nonveg', 'veg', 'vegan', 'keto', 'other'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_smoking
        CHECK (smoking IS NULL OR smoking IN ('no', 'occasionally', 'yes'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_alcohol
        CHECK (alcohol IS NULL OR alcohol IN ('no', 'occasionally', 'moderate', 'heavy'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_blood_group
        CHECK (blood_group IS NULL OR blood_group IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_pregnancy
        CHECK (pregnancy IS NULL OR pregnancy IN ('none', 'pregnant', 'breastfeeding', 'ttc'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_ethnicity
        CHECK (ethnicity IS NULL OR ethnicity IN ('asian', 'western', 'east_asian', 'african', 'other'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE health_records ADD CONSTRAINT chk_dosha_dominant
        CHECK (dosha_dominant IS NULL OR dosha_dominant IN ('vata', 'pitta', 'kapha'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    ALTER TABLE reports ADD CONSTRAINT chk_report_health_score
        CHECK (health_score IS NULL OR health_score BETWEEN 10 AND 100);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────
-- GAP 4: is_latest flag on health_records
-- ─────────────────────────────────────────────
ALTER TABLE health_records ADD COLUMN IF NOT EXISTS is_latest BOOLEAN DEFAULT TRUE;

CREATE OR REPLACE FUNCTION set_latest_health_record()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE health_records
    SET is_latest = FALSE
    WHERE user_id = NEW.user_id AND id != NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_set_latest_record ON health_records;
CREATE TRIGGER trg_set_latest_record
    AFTER INSERT ON health_records
    FOR EACH ROW EXECUTE FUNCTION set_latest_health_record();

-- ─────────────────────────────────────────────
-- GAP 5: Auto-update last_login on signin
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_last_login()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE profiles
    SET last_login = NOW()
    WHERE id = NEW.id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_login ON auth.sessions;
CREATE TRIGGER on_auth_user_login
    AFTER INSERT ON auth.sessions
    FOR EACH ROW EXECUTE FUNCTION update_last_login();

-- ─────────────────────────────────────────────
-- GAP 6: Composite & performance indexes
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_health_records_user_latest
    ON health_records(user_id, is_latest) WHERE is_latest = TRUE;

CREATE INDEX IF NOT EXISTS idx_health_records_user_date
    ON health_records(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_reports_user_date
    ON reports(user_id, generated_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_active
    ON profiles(is_active) WHERE is_active = TRUE;

-- ─────────────────────────────────────────────
-- GAP 7: GIN indexes for array columns
-- ─────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_health_records_conditions
    ON health_records USING GIN (conditions);

CREATE INDEX IF NOT EXISTS idx_health_records_goals
    ON health_records USING GIN (goals);

CREATE INDEX IF NOT EXISTS idx_reports_priorities
    ON reports USING GIN (top_priorities);

CREATE INDEX IF NOT EXISTS idx_reports_blood_tests
    ON reports USING GIN (blood_tests);

-- ─────────────────────────────────────────────
-- GAP 8: Audit log table
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
    action TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    details JSONB DEFAULT '{}',
    ip_address INET,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_date ON audit_log(created_at DESC);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own audit logs" ON audit_log
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "System can insert audit logs" ON audit_log
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- GAP 9: Update RLS to filter soft-deleted rows
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can view own health records" ON health_records;
CREATE POLICY "Users can view own health records" ON health_records
    FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

DROP POLICY IF EXISTS "Users can view own reports" ON reports;
CREATE POLICY "Users can view own reports" ON reports
    FOR SELECT USING (auth.uid() = user_id AND deleted_at IS NULL);

-- ─────────────────────────────────────────────
-- GAP 10: Update delete policy to soft delete
-- ─────────────────────────────────────────────
DROP POLICY IF EXISTS "Users can delete own health records" ON health_records;
CREATE POLICY "Users can update own health records" ON health_records
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can update own reports" ON reports
    FOR UPDATE USING (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- GAP 11: Soft delete helper function
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION soft_delete_record(
    p_table TEXT,
    p_record_id UUID
)
RETURNS VOID AS $$
BEGIN
    EXECUTE format('UPDATE %I SET deleted_at = NOW() WHERE id = $1 AND user_id = auth.uid()', p_table)
    USING p_record_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- DONE! All 11 gaps patched.
-- ============================================
