#!/bin/bash

# HealthNest Database Setup Script
# This script will DESTROY existing tables and create fresh ones
# Make sure you have the correct Supabase credentials before running

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load configuration from .env file
if [ ! -f .env ]; then
    echo -e "${RED}Error: .env file not found. Please create it with your Supabase credentials.${NC}"
    echo "Example .env file:"
    echo "SUPABASE_URL=https://your-project.supabase.co"
    echo "SUPABASE_ANON_KEY=your-anon-key-here"
    exit 1
fi

# Source the .env file
source .env

# Validate required variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ] || [ -z "$SUPABASE_DB_NAME" ] || [ -z "$SUPABASE_DB_PASSWORD" ]; then
    echo -e "${RED}Error: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_DB_NAME, and SUPABASE_DB_PASSWORD must be set in .env file${NC}"
    exit 1
fi

# Check if psql is installed
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql is not installed. Please install PostgreSQL client tools.${NC}"
    echo "On macOS: brew install postgresql"
    echo "On Ubuntu: sudo apt-get install postgresql-client"
    exit 1
fi

echo -e "${BLUE}HealthNest Database Setup Script${NC}"
echo -e "${YELLOW}WARNING: This script will DROP existing tables and create fresh ones!${NC}"
echo ""

# Confirm before proceeding
read -p "Are you sure you want to continue? This will DESTROY existing data! (yes/no): " confirm
if [[ $confirm != "yes" ]]; then
    echo -e "${YELLOW}Setup cancelled.${NC}"
    exit 0
fi

# Ask if user wants to include test data
read -p "Do you want to include test data (1 user, 2 patients, 4 health records)? (yes/no): " include_test_data

echo -e "${GREEN}Starting database setup...${NC}"

echo -e "${GREEN}Using Supabase URL: ${SUPABASE_URL}${NC}"
echo -e "${GREEN}Configuration loaded from .env file${NC}"

# Set up database connection
echo -e "${GREEN}Setting up database connection...${NC}"

# Extract project reference from URL
PROJECT_REF=$(echo "$SUPABASE_URL" | sed 's|https://||' | sed 's|\.supabase\.co||')

# Database connection details
DB_HOST="db.$PROJECT_REF.supabase.co"
DB_PORT="5432"
DB_NAME="postgres"
DB_USER="postgres.$PROJECT_REF"
DB_PASSWORD="$SUPABASE_DB_PASSWORD"

echo -e "${BLUE}Connecting to: $DB_HOST:$DB_PORT as $DB_USER@$DB_NAME${NC}"

echo -e "${YELLOW}Note: Direct database connection requires IP whitelist in Supabase dashboard.${NC}"
echo -e "${YELLOW}Creating SQL file for manual execution...${NC}"

# Create SQL file with all the setup commands
echo -e "${GREEN}Creating SQL setup file...${NC}"
cat > healthnest_setup.sql << 'EOF'
-- HealthNest Database Setup
-- This script will DROP existing tables and create fresh ones

-- Drop existing tables (if they exist)
DROP TABLE IF EXISTS health_records CASCADE;
DROP TABLE IF EXISTS patients CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop existing indexes (if they exist)
DROP INDEX IF EXISTS idx_health_records_patient_id;
DROP INDEX IF EXISTS idx_health_records_record_type;
DROP INDEX IF EXISTS idx_health_records_created_at;

-- Create Users Table
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  firstName TEXT NOT NULL,
  middleName TEXT,
  lastName TEXT,
  title TEXT,
  suffix TEXT,
  emails TEXT NOT NULL,
  phoneNumbers TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  preferences TEXT NOT NULL,
  onboardingCompleted BOOLEAN NOT NULL DEFAULT FALSE
);

-- Add comments for documentation
COMMENT ON TABLE users IS 'Stores user profile information and preferences';
COMMENT ON COLUMN users.id IS 'Unique identifier for the user (matches auth.uid())';
COMMENT ON COLUMN users.emails IS 'JSON array of email addresses';
COMMENT ON COLUMN users.phoneNumbers IS 'JSON array of phone numbers';
COMMENT ON COLUMN users.preferences IS 'JSON object containing user preferences';

-- Create Patients Table
CREATE TABLE patients (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  dateOfBirth TEXT NOT NULL,
  gender TEXT NOT NULL,
  abhaNumber TEXT,
  bloodGroup TEXT,
  emergencyContacts TEXT NOT NULL,
  preferences TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  hospitalIdentifiers TEXT NOT NULL,
  mobileNumbers TEXT NOT NULL
);

-- Add comments for documentation
COMMENT ON TABLE patients IS 'Stores patient information for family members';
COMMENT ON COLUMN patients.abhaNumber IS 'Ayushman Bharat Health Account number';
COMMENT ON COLUMN patients.emergencyContacts IS 'JSON array of emergency contact information';
COMMENT ON COLUMN patients.preferences IS 'JSON object containing patient preferences';
COMMENT ON COLUMN patients.hospitalIdentifiers IS 'JSON object mapping hospital names to patient IDs';
COMMENT ON COLUMN patients.mobileNumbers IS 'JSON array of mobile numbers';

-- Create Health Records Table
CREATE TABLE health_records (
  id TEXT PRIMARY KEY,
  patientId TEXT NOT NULL,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL,
  recordType TEXT NOT NULL,
  data TEXT NOT NULL,
  tags TEXT NOT NULL,
  source TEXT NOT NULL,
  documentPath TEXT,
  hospitalSystemName TEXT,
  hospitalIdentifierType TEXT,
  hospitalIdentifierValue TEXT,
  FOREIGN KEY (patientId) REFERENCES patients (id) ON DELETE CASCADE
);

-- Add comments for documentation
COMMENT ON TABLE health_records IS 'Stores all health-related documents and records';
COMMENT ON COLUMN health_records.recordType IS 'Type of health record (prescription, lab_report, scan_report, etc.)';
COMMENT ON COLUMN health_records.data IS 'JSON object containing extracted and structured health data';
COMMENT ON COLUMN health_records.tags IS 'JSON array of tags for categorization';
COMMENT ON COLUMN health_records.source IS 'Source of the record (scanned, manual, imported)';
COMMENT ON COLUMN health_records.documentPath IS 'Path to the original document file';
COMMENT ON COLUMN health_records.hospitalSystemName IS 'Name of the hospital system';
COMMENT ON COLUMN health_records.hospitalIdentifierType IS 'Type of hospital identifier (UHID, MRN, etc.)';
COMMENT ON COLUMN health_records.hospitalIdentifierValue IS 'Value of the hospital identifier';

-- Create indexes for better performance
CREATE INDEX idx_health_records_patient_id ON health_records(patientId);
CREATE INDEX idx_health_records_record_type ON health_records(recordType);
CREATE INDEX idx_health_records_created_at ON health_records(createdAt);

-- Enable Row Level Security (RLS)
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_records ENABLE ROW LEVEL SECURITY;

-- Users table policies
CREATE POLICY "Users can view own data" ON users
  FOR SELECT USING (auth.uid()::text = id);

CREATE POLICY "Users can insert own data" ON users
  FOR INSERT WITH CHECK (auth.uid()::text = id);

CREATE POLICY "Users can update own data" ON users
  FOR UPDATE USING (auth.uid()::text = id);

CREATE POLICY "Users can delete own data" ON users
  FOR DELETE USING (auth.uid()::text = id);

-- Patients table policies (for authenticated users)
CREATE POLICY "Authenticated users can view patients" ON patients
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert patients" ON patients
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update patients" ON patients
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete patients" ON patients
  FOR DELETE USING (auth.role() = 'authenticated');

-- Health records table policies
CREATE POLICY "Authenticated users can view health records" ON health_records
  FOR SELECT USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert health records" ON health_records
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update health records" ON health_records
  FOR UPDATE USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete health records" ON health_records
  FOR DELETE USING (auth.role() = 'authenticated');

-- Create optional database function for complex queries
CREATE OR REPLACE FUNCTION get_health_records_with_patient(patient_id TEXT)
RETURNS TABLE (
  record_id TEXT,
  patient_name TEXT,
  record_type TEXT,
  created_at TEXT,
  data JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    hr.id,
    p.name,
    hr.recordType,
    hr.createdAt,
    hr.data::jsonb
  FROM health_records hr
  JOIN patients p ON hr.patientId = p.id
  WHERE hr.patientId = patient_id
  ORDER BY hr.createdAt DESC;
END;
$$ LANGUAGE plpgsql;

-- Verify tables were created
SELECT 'Tables created successfully:' as status;
SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name IN ('users', 'patients', 'health_records') ORDER BY table_name;

-- Verify RLS is enabled
SELECT 'RLS policies created:' as status;
SELECT schemaname, tablename, policyname FROM pg_policies WHERE schemaname = 'public' ORDER BY tablename, policyname;

-- Verify indexes were created
SELECT 'Indexes created:' as status;
SELECT indexname FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'health_records' ORDER BY indexname;
EOF

echo -e "${GREEN}Executing database setup...${NC}"

echo -e "${GREEN}Executing database setup...${NC}"

echo -e "${GREEN}✅ SQL setup file created: healthnest_setup.sql${NC}"

# Note: Test data creation removed for security
echo -e "${YELLOW}Note: Test data creation has been removed for security reasons.${NC}"
echo -e "${YELLOW}Please create test data manually through the application UI.${NC}"
-- HealthNest Test Data
-- This script inserts test data for development and testing

-- Insert test user
INSERT INTO users (
  id,
  firstName,
  middleName,
  lastName,
  title,
  suffix,
  emails,
  phoneNumbers,
  createdAt,
  updatedAt,
  preferences,
  onboardingCompleted
) VALUES (
  'test-user-001',
  'Dr. Sarah',
  'Elizabeth',
  'Johnson',
  'Dr.',
  'MD',
  '["sarah.johnson@email.com", "dr.sarah@healthclinic.com"]',
  '["+91-98765-43210", "+91-87654-32109"]',
  '2024-01-15T10:30:00Z',
  '2024-01-15T10:30:00Z',
  '{"theme": "light", "notifications": true, "language": "en", "timezone": "Asia/Kolkata"}',
  true
);

-- Insert test patient 1 (family member)
INSERT INTO patients (
  id,
  name,
  dateOfBirth,
  gender,
  abhaNumber,
  bloodGroup,
  emergencyContacts,
  preferences,
  createdAt,
  updatedAt,
  hospitalIdentifiers,
  mobileNumbers
) VALUES (
  'patient-001',
  'Rahul Kumar Sharma',
  '1985-03-15',
  'Male',
  '1234-5678-9012-3456',
  'B+',
  '[
    {"name": "Priya Sharma", "relationship": "Wife", "phone": "+91-98765-43211", "email": "priya.sharma@email.com"},
    {"name": "Dr. Amit Patel", "relationship": "Primary Care", "phone": "+91-87654-32108", "email": "dr.amit@cityhospital.com"}
  ]',
  '{"allergies": ["Penicillin", "Sulfa drugs"], "dietary": "Vegetarian", "language": "Hindi"}',
  '2024-01-15T11:00:00Z',
  '2024-01-15T11:00:00Z',
  '{
    "City General Hospital": {"UHID": "CGH-2024-001234", "MRN": "M123456"},
    "Apollo Hospital": {"UHID": "APH-2024-567890", "MRN": "A789012"},
    "Fortis Hospital": {"UHID": "FTH-2024-345678", "MRN": "F456789"}
  }',
  '["+91-98765-43212", "+91-87654-32107"]'
);

-- Insert test patient 2 (family member)
INSERT INTO patients (
  id,
  name,
  dateOfBirth,
  gender,
  abhaNumber,
  bloodGroup,
  emergencyContacts,
  preferences,
  createdAt,
  updatedAt,
  hospitalIdentifiers,
  mobileNumbers
) VALUES (
  'patient-002',
  'Anjali Sharma',
  '1990-07-22',
  'Female',
  '2345-6789-0123-4567',
  'O+',
  '[
    {"name": "Rahul Sharma", "relationship": "Husband", "phone": "+91-98765-43212", "email": "rahul.sharma@email.com"},
    {"name": "Dr. Meera Singh", "relationship": "Gynecologist", "phone": "+91-87654-32106", "email": "dr.meera@womensclinic.com"}
  ]',
  '{"allergies": ["Latex"], "dietary": "Non-vegetarian", "language": "English"}',
  '2024-01-15T11:30:00Z',
  '2024-01-15T11:30:00Z',
  '{
    "Women''s Health Clinic": {"UHID": "WHC-2024-789012", "MRN": "W345678"},
    "Apollo Hospital": {"UHID": "APH-2024-901234", "MRN": "A567890"}
  }',
  '["+91-98765-43213", "+91-87654-32105"]'
);

-- Insert sample health records for Rahul
INSERT INTO health_records (
  id,
  patientId,
  createdAt,
  updatedAt,
  recordType,
  data,
  tags,
  source,
  documentPath,
  hospitalSystemName,
  hospitalIdentifierType,
  hospitalIdentifierValue
) VALUES (
  'record-001',
  'patient-001',
  '2024-01-10T09:00:00Z',
  '2024-01-10T09:00:00Z',
  'lab_report',
  '{
    "testName": "Complete Blood Count",
    "results": {
      "hemoglobin": "14.2 g/dL",
      "whiteBloodCells": "7.5 x 10^9/L",
      "platelets": "250 x 10^9/L",
      "redBloodCells": "4.8 x 10^12/L"
    },
    "referenceRange": "Normal",
    "labName": "City Lab Services",
    "orderedBy": "Dr. Amit Patel"
  }',
  '["blood test", "CBC", "routine"]',
  'scanned',
  '/documents/rahul_cbc_20240110.pdf',
  'City General Hospital',
  'UHID',
  'CGH-2024-001234'
);

INSERT INTO health_records (
  id,
  patientId,
  createdAt,
  updatedAt,
  recordType,
  data,
  tags,
  source,
  documentPath,
  hospitalSystemName,
  hospitalIdentifierType,
  hospitalIdentifierValue
) VALUES (
  'record-002',
  'patient-001',
  '2024-01-12T14:30:00Z',
  '2024-01-12T14:30:00Z',
  'prescription',
  '{
    "medication": "Metformin 500mg",
    "dosage": "1 tablet twice daily",
    "duration": "30 days",
    "instructions": "Take with meals",
    "prescribedBy": "Dr. Amit Patel",
    "diagnosis": "Type 2 Diabetes",
    "refills": 2
  }',
  '["diabetes", "metformin", "prescription"]',
  'scanned',
  '/documents/rahul_metformin_20240112.pdf',
  'City General Hospital',
  'UHID',
  'CGH-2024-001234'
);

-- Insert sample health records for Anjali
INSERT INTO health_records (
  id,
  patientId,
  createdAt,
  updatedAt,
  recordType,
  data,
  tags,
  source,
  documentPath,
  hospitalSystemName,
  hospitalIdentifierType,
  hospitalIdentifierValue
) VALUES (
  'record-003',
  'patient-002',
  '2024-01-08T11:00:00Z',
  '2024-01-08T11:00:00Z',
  'scan_report',
  '{
    "scanType": "Ultrasound",
    "bodyPart": "Abdomen",
    "findings": "Normal liver, gallbladder, and kidneys. No abnormalities detected.",
    "radiologist": "Dr. Rajesh Kumar",
    "impression": "Normal abdominal ultrasound",
    "recommendations": "No follow-up required"
  }',
  '["ultrasound", "abdomen", "normal"]',
  'scanned',
  '/documents/anjali_ultrasound_20240108.pdf',
  'Women''s Health Clinic',
  'UHID',
  'WHC-2024-789012'
);

INSERT INTO health_records (
  id,
  patientId,
  createdAt,
  updatedAt,
  recordType,
  data,
  tags,
  source,
  documentPath,
  hospitalSystemName,
  hospitalIdentifierType,
  hospitalIdentifierValue
) VALUES (
  'record-004',
  'patient-002',
  '2024-01-14T16:00:00Z',
  '2024-01-14T16:00:00Z',
  'prescription',
  '{
    "medication": "Folic Acid 5mg",
    "dosage": "1 tablet daily",
    "duration": "90 days",
    "instructions": "Take in the morning",
    "prescribedBy": "Dr. Meera Singh",
    "diagnosis": "Pregnancy Supplement",
    "refills": 1
  }',
  '["pregnancy", "folic acid", "supplement"]',
  'scanned',
  '/documents/anjali_folic_acid_20240114.pdf',
  'Women''s Health Clinic',
  'UHID',
  'WHC-2024-789012'
);

-- Verify the data was inserted
SELECT 'Test data inserted successfully!' as status;
SELECT 'Users:' as table_name, COUNT(*) as count FROM users;
SELECT 'Patients:' as table_name, COUNT(*) as count FROM patients;
SELECT 'Health Records:' as table_name, COUNT(*) as count FROM health_records;
EOF
    echo -e "${GREEN}✅ Test data file created: test_data.sql${NC}"
fi

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Go to your Supabase dashboard: $SUPABASE_URL"
echo "2. Navigate to SQL Editor"
echo "3. Copy and paste the contents of healthnest_setup.sql"
echo "4. Click 'Run' to execute the setup"

echo ""
echo -e "${YELLOW}Alternative: Enable IP access in Supabase dashboard to use direct connection${NC}"
echo -e "${YELLOW}1. Go to Settings > Database > Connection pooling${NC}"
echo -e "${YELLOW}2. Add your IP address to the allowed list${NC}"
echo ""
echo -e "${GREEN}Your HealthNest database setup is ready!${NC}"

echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "1. Execute the SQL in your Supabase dashboard"
echo "2. Run the HealthNest app: flutter run"
echo "3. Test the database connection in the app"
