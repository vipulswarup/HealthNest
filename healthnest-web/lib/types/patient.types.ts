import { MobileNumber } from './user.types';

export interface HospitalIdentifier {
  systemName: string;
  identifierType: string;
  value: string;
}

export interface Patient {
  _id?: string;
  id?: string;
  userId: string;
  firstName: string;
  middleName?: string;
  lastName?: string;
  title?: string;
  suffix?: string;
  emails: string[];
  dateOfBirth: Date;
  gender: string;
  abhaNumber?: string;
  bloodGroup?: string;
  emergencyContacts: string[];
  preferences: Record<string, any>;
  createdAt: Date;
  updatedAt: Date;
  hospitalIdentifiers: HospitalIdentifier[];
  mobileNumbers: MobileNumber[];
}

export interface CreatePatientInput {
  userId: string;
  firstName: string;
  middleName?: string;
  lastName?: string;
  title?: string;
  suffix?: string;
  emails?: string[];
  dateOfBirth: Date;
  gender: string;
  abhaNumber?: string;
  bloodGroup?: string;
  emergencyContacts?: string[];
  preferences?: Record<string, any>;
  hospitalIdentifiers?: HospitalIdentifier[];
  mobileNumbers?: MobileNumber[];
}

export interface UpdatePatientInput {
  firstName?: string;
  middleName?: string;
  lastName?: string;
  title?: string;
  suffix?: string;
  emails?: string[];
  dateOfBirth?: Date;
  gender?: string;
  abhaNumber?: string;
  bloodGroup?: string;
  emergencyContacts?: string[];
  preferences?: Record<string, any>;
  hospitalIdentifiers?: HospitalIdentifier[];
  mobileNumbers?: MobileNumber[];
}

