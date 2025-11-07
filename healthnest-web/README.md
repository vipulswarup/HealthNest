# HealthNest Web Application

A web-first health record management system built with Next.js, MongoDB, and React.

## Tech Stack

- **Frontend**: Next.js 16 (App Router), React 19, TypeScript, Tailwind CSS
- **Backend**: Next.js API Routes
- **Database**: MongoDB Atlas
- **Authentication**: NextAuth.js
- **File Storage**: Cloudflare R2
- **AI Processing**: Groq (Llama 3.3 70B)
- **OCR**: Tesseract (hosted on VM)

## Prerequisites

- Node.js 18+ and npm
- MongoDB Atlas account
- Cloudflare R2 account
- Groq API key
- Tesseract OCR service (optional for initial setup)

## Setup Instructions

### 1. Install Dependencies

```bash
npm install
```

### 2. Environment Variables

Copy `.env.example` to `.env` and fill in your credentials:

```bash
cp .env.example .env
```

Required environment variables:

- `MONGODB_URI`: Your MongoDB Atlas connection string
- `MONGODB_DB_NAME`: Database name (default: `healthnest`)
- `NEXTAUTH_URL`: Your app URL (e.g., `http://localhost:3000`)
- `NEXTAUTH_SECRET`: Generate with `openssl rand -base64 32`
- `R2_ACCOUNT_ID`: Cloudflare R2 account ID
- `R2_ACCESS_KEY_ID`: Cloudflare R2 access key
- `R2_SECRET_ACCESS_KEY`: Cloudflare R2 secret key
- `R2_BUCKET_NAME`: R2 bucket name
- `R2_PUBLIC_URL`: Public URL for R2 bucket (optional)
- `GROQ_API_KEY`: Groq API key for AI processing
- `OCR_SERVICE_URL`: URL of Tesseract OCR service (optional)

Optional OAuth:
- `GOOGLE_CLIENT_ID`: Google OAuth client ID
- `GOOGLE_CLIENT_SECRET`: Google OAuth client secret

### 3. Initialize Database

Run the database initialization script to create indexes:

```bash
npm run init-db
```

### 4. Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) in your browser.

## Project Structure

```
healthnest-web/
├── app/                    # Next.js app router
│   ├── api/               # API routes
│   └── ...
├── lib/                   # Core libraries
│   ├── auth/             # Authentication config
│   ├── db/               # Database utilities
│   ├── middleware/       # Middleware functions
│   ├── types/            # TypeScript types
│   ├── mongodb.ts        # MongoDB connection
│   └── r2.ts             # Cloudflare R2 client
├── scripts/              # Utility scripts
├── types/                # Global type definitions
└── ...
```

## Development

### Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run lint` - Run ESLint
- `npm run init-db` - Initialize MongoDB indexes

## API Endpoints

### Authentication
- `POST /api/auth/signin` - Sign in
- `POST /api/auth/signup` - Sign up
- `GET /api/auth/session` - Get current session

### Users
- `GET /api/users/me` - Get current user
- `PUT /api/users/me` - Update current user

### Patients
- `GET /api/patients` - List patients
- `POST /api/patients` - Create patient
- `GET /api/patients/:id` - Get patient
- `PUT /api/patients/:id` - Update patient
- `DELETE /api/patients/:id` - Delete patient

### Health Records
- `GET /api/health-records` - List health records
- `POST /api/health-records` - Create health record
- `GET /api/health-records/:id` - Get health record
- `PUT /api/health-records/:id` - Update health record
- `DELETE /api/health-records/:id` - Delete health record

### Medications
- `GET /api/medications` - List medications
- `POST /api/medications` - Create medication
- `GET /api/medications/:id` - Get medication
- `PUT /api/medications/:id` - Update medication
- `DELETE /api/medications/:id` - Delete medication

## Database Schema

### Collections

- `users` - App users/owners
- `patients` - Family member patient profiles
- `health_records` - Health records and documents
- `medications` - Medication prescriptions
- `medication_doses` - Medication dose logs
- `medication_reminders` - Medication reminders

## License

See LICENSE file in the root directory.
