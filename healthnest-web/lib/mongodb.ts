import { MongoClient, Db } from 'mongodb';

function getMongoConfig() {
  if (!process.env.MONGODB_URI) {
    throw new Error('Please add your Mongo URI to .env');
  }

  if (!process.env.MONGODB_DB_NAME) {
    throw new Error('Please add your Mongo DB name to .env');
  }

  return {
    uri: process.env.MONGODB_URI,
    dbName: process.env.MONGODB_DB_NAME,
  };
}

let client: MongoClient;
let clientPromise: Promise<MongoClient> | null = null;

function getClientPromise(): Promise<MongoClient> {
  if (clientPromise) {
    return clientPromise;
  }

  const config = getMongoConfig();

  if (process.env.NODE_ENV === 'development') {
    let globalWithMongo = global as typeof globalThis & {
      _mongoClientPromise?: Promise<MongoClient>;
    };

    if (!globalWithMongo._mongoClientPromise) {
      client = new MongoClient(config.uri);
      globalWithMongo._mongoClientPromise = client.connect();
    }
    clientPromise = globalWithMongo._mongoClientPromise;
  } else {
    client = new MongoClient(config.uri);
    clientPromise = client.connect();
  }

  return clientPromise;
}

export async function getDatabase(): Promise<Db> {
  const config = getMongoConfig();
  const client = await getClientPromise();
  return client.db(config.dbName);
}

export default getClientPromise;

