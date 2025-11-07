# Supabase Setup for HealthNest

This guide will help you set up Supabase for the HealthNest application.

## 1. Supabase Project Setup

1. Go to [supabase.com](https://supabase.com) and create a new project
2. Note down your project URL and anon key from the API settings

## 2. Database Schema

Create the following tables in your Supabase database. Run these SQL commands in your Supabase SQL Editor:

### Users Table
```sql
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
```

### Patients Table
```sql
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
```

### Health Records Table
```sql
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
```

## 3. Row Level Security (RLS)

Enable RLS and create policies for data security. This ensures that users can only access their own data:

```sql
-- Enable RLS on all tables
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

-- Patients table policies (assuming patients belong to users)
-- Note: You may need to add a userId column to patients table for proper RLS
-- For now, we'll allow all authenticated users to access patients
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
```

## 4. Environment Configuration

### Option 1: Using .env file (Recommended for Development)

1. **Create a `.env` file** in the project root:
   ```bash
   # Supabase Configuration
   SUPABASE_URL=https://your-project.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ```

2. **Copy from example**:
   ```bash
   cp .env.example .env
   # Then edit .env with your actual values
   ```

### Option 2: Using Environment Variables

#### For Development
```bash
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key-here"
```

#### For Flutter Run
```bash
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

#### For Production Build
```bash
flutter build macos --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key-here
```

### Security Notes
- The `.env` file is automatically ignored by Git (see `.gitignore`)
- Never commit your actual Supabase keys to version control
- Use different keys for development, staging, and production environments

## 5. Testing the Connection

### Quick Test
Run the app and check the console for any connection errors. The app should:
1. Initialize Supabase successfully
2. Create an anonymous session
3. Be able to read/write data to the database

### Manual Testing
You can also test the connection manually using the Supabase dashboard:

1. **Check Authentication**: Go to Authentication > Users to see if anonymous users are being created
2. **Check Database**: Go to Table Editor to see if data is being inserted
3. **Check Logs**: Go to Logs to see any errors or issues

### Expected Console Output
```
flutter: supabase.supabase_flutter: INFO: ***** Supabase init completed *****
flutter: UserProvider: initialize called
flutter: UserProvider: initializing storage
flutter: UserProvider: initialization complete
```

## 6. Troubleshooting

### Common Issues:

1. **Authentication Error**: 
   - Check if your anon key is correct
   - Verify the key is from the correct project
   - Ensure the key has the right permissions

2. **Table Not Found**: 
   - Ensure all tables are created with exact names: `users`, `patients`, `health_records`
   - Check that the SQL commands were executed successfully
   - Verify table names in the Supabase dashboard

3. **RLS Policy Error**: 
   - Check if RLS policies allow the operations you're trying to perform
   - Verify that anonymous authentication is enabled
   - Check if the user is properly authenticated

4. **Network Error**: 
   - Ensure your device has internet connectivity
   - Check if Supabase is accessible from your network
   - Verify the project URL is correct

5. **Environment Variable Issues**:
   - Check if `.env` file exists and has correct values
   - Verify environment variables are being loaded
   - Check console for "Warning: .env file not found" messages

### Debug Mode:
The app includes debug logging for Supabase operations. Check the console output for detailed error messages.

### Getting Help:
- Check the [Supabase Documentation](https://supabase.com/docs)
- Review the [Flutter Supabase Documentation](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- Check the app's console output for specific error messages

## 7. Additional Configuration

### Enable Anonymous Authentication
In your Supabase dashboard, go to Authentication > Settings and enable "Enable anonymous sign-ins" if you want to use anonymous authentication.

### Storage Bucket (Optional)
If you plan to store document files in Supabase Storage:

```sql
-- Create a storage bucket for health documents
INSERT INTO storage.buckets (id, name, public) 
VALUES ('health-documents', 'health-documents', false);

-- Create policy for authenticated users
CREATE POLICY "Authenticated users can upload documents" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'health-documents' AND auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can view documents" ON storage.objects
  FOR SELECT USING (bucket_id = 'health-documents' AND auth.role() = 'authenticated');
```

### Real-time Subscriptions (Optional)
The app supports real-time updates. To enable them, ensure real-time is enabled in your Supabase project settings.

### Database Functions (Optional)
You can create custom database functions for complex queries:

```sql
-- Function to get health records with patient information
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
```
