/**
 * Daddies Padel — Firestore Seeder
 *
 * Usage:
 *   1. Download service account key from Firebase Console:
 *      Project Settings → Service Accounts → Generate New Private Key
 *   2. Save as scripts/serviceAccountKey.json
 *   3. Run: node seed_firestore.js
 */

const admin = require('firebase-admin');
const path = require('path');

const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'serviceAccountKey.json');

if (!require('fs').existsSync(SERVICE_ACCOUNT_PATH)) {
  console.error('❌ serviceAccountKey.json not found!');
  console.error('   Download from Firebase Console → Project Settings → Service Accounts');
  process.exit(1);
}

const serviceAccount = require(SERVICE_ACCOUNT_PATH);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: 'padel-daddies',
});

const db = admin.firestore();
const now = new Date();
const DAY = 86400000;

function daysAgo(d) { return new Date(now.getTime() - d * DAY); }
function daysFromNow(d) { return new Date(now.getTime() + d * DAY); }
function hoursAgo(h) { return new Date(now.getTime() - h * 3600000); }

// ============================================================
// DATA
// ============================================================

const users = [
  { id: 'user-reza',   name: 'Reza Rahadian',  phone: '08119990001', role: 'superAdmin', nickname: 'Reza',   bio: 'Founder Daddies Padel Community. Suka ngajak main & ngumpul bareng.', skillLevel: 'mahir',    chipsBalance: 500, referralCode: 'REZA001', createdAt: daysAgo(180) },
  { id: 'user-hendy',  name: 'Hendy Wijaya',   phone: '08119990002', role: 'mimin',      nickname: 'Hendy',  bio: 'Mimin andalan yang selalu rajin booking court. Backhand enthusiast.',  skillLevel: 'mahir',    chipsBalance: 350, referralCode: 'HENDY02', createdAt: daysAgo(170) },
  { id: 'user-bima',   name: 'Bima Sakti',     phone: '08119990003', role: 'mimin',      nickname: 'Bima',   bio: 'Mimin night session. Kalau bola mental, dia yang paling semangat.',   skillLevel: 'menengah', chipsBalance: 280, referralCode: 'BIMA003', createdAt: daysAgo(165) },
  { id: 'user-fajar',  name: 'Fajar Nugroho',  phone: '08119990004', role: 'bendahara',  nickname: 'Fajar',  bio: 'Bendahara yang selalu tepat hitung. Juga jago lob!',                  skillLevel: 'menengah', chipsBalance: 200, referralCode: 'FAJAR04', createdAt: daysAgo(160) },
  { id: 'user-arif',   name: 'Arif Budiman',   phone: '08129990005', role: 'member',     nickname: 'Arif',   bio: 'Newbie yang progresnya cepat. Suka drill pagi-pagi.',                 skillLevel: 'pemula',   chipsBalance: 150, referralCode: 'ARIF005', createdAt: daysAgo(120) },
  { id: 'user-denny',  name: 'Denny Pratama',  phone: '08139990006', role: 'member',     nickname: 'Den',    bio: 'Pemain all-round. Bisa main depan, bisa main belakang.',              skillLevel: 'menengah', chipsBalance: 175, referralCode: 'DEN006',  createdAt: daysAgo(110) },
  { id: 'user-gilang', name: 'Gilang Ramadhan', phone: '08159990007', role: 'member',    nickname: 'Gilang', bio: 'Smash keras, tapi kadang keluar. Semangat terus!',                    skillLevel: 'pemula',   chipsBalance: 100, referralCode: 'GILANG7', createdAt: daysAgo(100) },
  { id: 'user-raka',   name: 'Raka Aditya',    phone: '08179990008', role: 'member',     nickname: 'Raka',   bio: 'Si strategis yang suka main placement. Tenang tapi mematikan.',       skillLevel: 'mahir',    chipsBalance: 400, referralCode: 'RAKA008', createdAt: daysAgo(95)  },
  { id: 'user-tommy',  name: 'Tommy Hartono',  phone: '08189990009', role: 'member',     nickname: 'Tom',    bio: 'Tembok pertahanan. Susah dilewati kalau jaga belakang.',              skillLevel: 'menengah', chipsBalance: 125, referralCode: 'TOM009',  createdAt: daysAgo(80)  },
  { id: 'user-andre',  name: 'Andre Kusuma',   phone: '08199990010', role: 'member',     nickname: 'Andre',  bio: 'Spesialis net play. Volley-nya tajam dan akurat.',                    skillLevel: 'mahir',    chipsBalance: 225, referralCode: 'ANDRE10', createdAt: daysAgo(70)  },
  { id: 'user-bayu',   name: 'Bayu Pratomo',   phone: '08211990011', role: 'member',     nickname: 'Bayu',   bio: 'Morning person yang suka padel sebelum ngantor.',                     skillLevel: 'pemula',   chipsBalance: 75,  referralCode: 'BAYU011', createdAt: daysAgo(45)  },
  { id: 'user-cahyo',  name: 'Cahyo Wibowo',   phone: '08221990012', role: 'member',     nickname: 'Cah',    bio: 'Weekend warrior. Cuma bisa main Sabtu-Minggu tapi serius!',           skillLevel: 'pemula',   chipsBalance: 50,  referralCode: 'CAH012',  createdAt: daysAgo(30)  },
];

const venues = [
  { id: 'venue-genesis', name: 'Genesis Padel', address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera, Tangerang Selatan', bio: 'Genesis Padel adalah venue padel premium pertama di kawasan Alam Sutera.', phone: '021-29880123', facilities: ['Indoor Courts', 'Parkir Luas', 'Musholla', 'Kantin', 'Pro Shop', 'Shower & Locker'], courtCount: 4, openHours: '06:00 - 23:00' },
  { id: 'venue-haus',    name: 'Padel Haus BSD', address: 'Jl. BSD Grand Boulevard, BSD City, Tangerang Selatan', bio: 'Padel Haus BSD hadir dengan konsep modern-industrial yang kekinian.', phone: '021-53167890', facilities: ['Indoor Courts', 'Café & Lounge', 'Parkir Luas', 'Shower', 'Free WiFi', 'Rental Raket'], courtCount: 3, openHours: '07:00 - 22:00' },
  { id: 'venue-pik',     name: 'The Padel Club PIK', address: 'Jl. Pantai Indah Utara 2, Pantai Indah Kapuk, Jakarta Utara', bio: 'The Padel Club PIK adalah destinasi padel eksklusif di kawasan PIK.', phone: '021-66601234', facilities: ['Semi-Outdoor Courts', 'Restaurant', 'Valet Parking', 'Shower & Locker', 'Pro Shop', 'Kids Area'], courtCount: 5, openHours: '06:00 - 22:00' },
];

const sessions = [
  { id: 'session-1', miminId: 'user-hendy', miminName: 'Hendy Wijaya', title: 'Mabar Sabtu Sore',        venue: 'Genesis Padel',       date: daysAgo(28),          timeStart: '16:00', timeEnd: '18:00', maxPlayers: 8,  pricePerPlayer: 150000, status: 'completed', courtNumber: 2, notes: 'Bawa bola sendiri ya!', confirmedCount: 8, createdAt: daysAgo(32) },
  { id: 'session-2', miminId: 'user-bima',  miminName: 'Bima Sakti',   title: 'Rabu Siang Chill',        venue: 'Padel Haus BSD',      date: daysAgo(21),          timeStart: '12:00', timeEnd: '14:00', maxPlayers: 8,  pricePerPlayer: 125000, status: 'completed', confirmedCount: 6, createdAt: daysAgo(25) },
  { id: 'session-3', miminId: 'user-hendy', miminName: 'Hendy Wijaya', title: 'Friday Night Smash',      venue: 'The Padel Club PIK',  date: daysAgo(14),          timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8,  pricePerPlayer: 200000, status: 'completed', courtNumber: 1, notes: 'Night session, pakai sepatu indoor', confirmedCount: 8, createdAt: daysAgo(18) },
  { id: 'session-4', miminId: 'user-bima',  miminName: 'Bima Sakti',   title: 'Weekend Warriors',        venue: 'Genesis Padel',       date: daysAgo(7),           timeStart: '08:00', timeEnd: '10:00', maxPlayers: 8,  pricePerPlayer: 150000, status: 'completed', confirmedCount: 7, createdAt: daysAgo(10) },
  { id: 'session-5', miminId: 'user-bima',  miminName: 'Bima Sakti',   title: 'Jumat Night Session',     venue: 'Padel Haus BSD',      date: daysFromNow(2),       timeStart: '19:00', timeEnd: '21:00', maxPlayers: 8,  pricePerPlayer: 175000, status: 'locked',    courtNumber: 3, confirmedCount: 7, createdAt: daysAgo(5) },
  { id: 'session-6', miminId: 'user-hendy', miminName: 'Hendy Wijaya', title: 'Sunday Funday',           venue: 'The Padel Club PIK',  date: daysFromNow(4),       timeStart: '09:00', timeEnd: '11:00', maxPlayers: 8,  pricePerPlayer: 200000, status: 'open',      courtNumber: 4, notes: 'Pemula welcome! Kita main santai.', confirmedCount: 5, createdAt: daysAgo(3) },
  { id: 'session-7', miminId: 'user-hendy', miminName: 'Hendy Wijaya', title: 'Senin Pagi Semangat',     venue: 'Padel Haus BSD',      date: daysFromNow(8),       timeStart: '07:00', timeEnd: '09:00', maxPlayers: 8,  pricePerPlayer: 125000, status: 'open',      confirmedCount: 2, createdAt: daysAgo(1) },
  { id: 'session-8', miminId: 'user-reza',  miminName: 'Reza Rahadian',title: 'Daddies Cup Mini Tournament', venue: 'Genesis Padel',  date: daysFromNow(15),      timeStart: '08:00', timeEnd: '12:00', maxPlayers: 16, pricePerPlayer: 250000, status: 'draft',     courtNumber: 1, notes: 'Mini tournament! Round robin lalu semifinal.', confirmedCount: 0, createdAt: now },
];

const slots = [
  // Session 1 (completed, 8 locked)
  { id: 'slot-1a', sessionId: 'session-1', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1b', sessionId: 'session-1', userId: 'user-denny',  userName: 'Denny Pratama',  status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1c', sessionId: 'session-1', userId: 'user-gilang', userName: 'Gilang Ramadhan',status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1d', sessionId: 'session-1', userId: 'user-raka',   userName: 'Raka Aditya',    status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1e', sessionId: 'session-1', userId: 'user-hendy',  userName: 'Hendy Wijaya',   status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1f', sessionId: 'session-1', userId: 'user-bima',   userName: 'Bima Sakti',     status: 'locked', joinedAt: daysAgo(30), confirmedAt: daysAgo(29) },
  { id: 'slot-1g', sessionId: 'session-1', userId: 'user-fajar',  userName: 'Fajar Nugroho',  status: 'locked', joinedAt: daysAgo(29), confirmedAt: daysAgo(29) },
  { id: 'slot-1h', sessionId: 'session-1', userId: 'user-reza',   userName: 'Reza Rahadian',  status: 'locked', joinedAt: daysAgo(29), confirmedAt: daysAgo(29) },
  // Session 2 (completed, 6 locked)
  { id: 'slot-2a', sessionId: 'session-2', userId: 'user-denny',  userName: 'Denny Pratama',  status: 'locked', joinedAt: daysAgo(23), confirmedAt: daysAgo(22) },
  { id: 'slot-2b', sessionId: 'session-2', userId: 'user-gilang', userName: 'Gilang Ramadhan',status: 'locked', joinedAt: daysAgo(23), confirmedAt: daysAgo(22) },
  { id: 'slot-2c', sessionId: 'session-2', userId: 'user-bima',   userName: 'Bima Sakti',     status: 'locked', joinedAt: daysAgo(23), confirmedAt: daysAgo(22) },
  { id: 'slot-2d', sessionId: 'session-2', userId: 'user-tommy',  userName: 'Tommy Hartono',  status: 'locked', joinedAt: daysAgo(22), confirmedAt: daysAgo(22) },
  { id: 'slot-2e', sessionId: 'session-2', userId: 'user-andre',  userName: 'Andre Kusuma',   status: 'locked', joinedAt: daysAgo(22), confirmedAt: daysAgo(22) },
  { id: 'slot-2f', sessionId: 'session-2', userId: 'user-fajar',  userName: 'Fajar Nugroho',  status: 'locked', joinedAt: daysAgo(22), confirmedAt: daysAgo(22) },
  // Session 3 (completed, 8 locked)
  { id: 'slot-3a', sessionId: 'session-3', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'locked', joinedAt: daysAgo(16), confirmedAt: daysAgo(15) },
  { id: 'slot-3b', sessionId: 'session-3', userId: 'user-raka',   userName: 'Raka Aditya',    status: 'locked', joinedAt: daysAgo(16), confirmedAt: daysAgo(15) },
  { id: 'slot-3c', sessionId: 'session-3', userId: 'user-hendy',  userName: 'Hendy Wijaya',   status: 'locked', joinedAt: daysAgo(16), confirmedAt: daysAgo(15) },
  { id: 'slot-3d', sessionId: 'session-3', userId: 'user-tommy',  userName: 'Tommy Hartono',  status: 'locked', joinedAt: daysAgo(15), confirmedAt: daysAgo(15) },
  { id: 'slot-3e', sessionId: 'session-3', userId: 'user-andre',  userName: 'Andre Kusuma',   status: 'locked', joinedAt: daysAgo(15), confirmedAt: daysAgo(15) },
  { id: 'slot-3f', sessionId: 'session-3', userId: 'user-denny',  userName: 'Denny Pratama',  status: 'locked', joinedAt: daysAgo(15), confirmedAt: daysAgo(15) },
  { id: 'slot-3g', sessionId: 'session-3', userId: 'user-gilang', userName: 'Gilang Ramadhan',status: 'locked', joinedAt: daysAgo(15), confirmedAt: daysAgo(14) },
  { id: 'slot-3h', sessionId: 'session-3', userId: 'user-fajar',  userName: 'Fajar Nugroho',  status: 'locked', joinedAt: daysAgo(15), confirmedAt: daysAgo(14) },
  // Session 4 (completed, 7 locked)
  { id: 'slot-4a', sessionId: 'session-4', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'locked', joinedAt: daysAgo(9), confirmedAt: daysAgo(8) },
  { id: 'slot-4b', sessionId: 'session-4', userId: 'user-denny',  userName: 'Denny Pratama',  status: 'locked', joinedAt: daysAgo(9), confirmedAt: daysAgo(8) },
  { id: 'slot-4c', sessionId: 'session-4', userId: 'user-raka',   userName: 'Raka Aditya',    status: 'locked', joinedAt: daysAgo(9), confirmedAt: daysAgo(8) },
  { id: 'slot-4d', sessionId: 'session-4', userId: 'user-bima',   userName: 'Bima Sakti',     status: 'locked', joinedAt: daysAgo(9), confirmedAt: daysAgo(8) },
  { id: 'slot-4e', sessionId: 'session-4', userId: 'user-bayu',   userName: 'Bayu Pratomo',   status: 'locked', joinedAt: daysAgo(8), confirmedAt: daysAgo(8) },
  { id: 'slot-4f', sessionId: 'session-4', userId: 'user-cahyo',  userName: 'Cahyo Wibowo',   status: 'locked', joinedAt: daysAgo(8), confirmedAt: daysAgo(8) },
  { id: 'slot-4g', sessionId: 'session-4', userId: 'user-tommy',  userName: 'Tommy Hartono',  status: 'locked', joinedAt: daysAgo(8), confirmedAt: daysAgo(8) },
  // Session 5 (locked upcoming — 6 paid, 1 confirmed, 1 waitlist)
  { id: 'slot-5a', sessionId: 'session-5', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'paid',      joinedAt: daysAgo(4), confirmedAt: daysAgo(3) },
  { id: 'slot-5b', sessionId: 'session-5', userId: 'user-denny',  userName: 'Denny Pratama',  status: 'paid',      joinedAt: daysAgo(4), confirmedAt: daysAgo(3) },
  { id: 'slot-5c', sessionId: 'session-5', userId: 'user-gilang', userName: 'Gilang Ramadhan',status: 'paid',      joinedAt: daysAgo(4), confirmedAt: daysAgo(3) },
  { id: 'slot-5d', sessionId: 'session-5', userId: 'user-raka',   userName: 'Raka Aditya',    status: 'paid',      joinedAt: daysAgo(3), confirmedAt: daysAgo(2) },
  { id: 'slot-5e', sessionId: 'session-5', userId: 'user-bima',   userName: 'Bima Sakti',     status: 'paid',      joinedAt: daysAgo(4), confirmedAt: daysAgo(3) },
  { id: 'slot-5f', sessionId: 'session-5', userId: 'user-fajar',  userName: 'Fajar Nugroho',  status: 'paid',      joinedAt: daysAgo(3), confirmedAt: daysAgo(2) },
  { id: 'slot-5g', sessionId: 'session-5', userId: 'user-hendy',  userName: 'Hendy Wijaya',   status: 'confirmed', joinedAt: daysAgo(2), confirmedAt: daysAgo(1) },
  { id: 'slot-5h', sessionId: 'session-5', userId: 'user-tommy',  userName: 'Tommy Hartono',  status: 'waitlist',  joinedAt: daysAgo(1) },
  // Session 6 (open — 5 confirmed)
  { id: 'slot-6a', sessionId: 'session-6', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'confirmed', joinedAt: daysAgo(2), confirmedAt: daysAgo(2) },
  { id: 'slot-6b', sessionId: 'session-6', userId: 'user-andre',  userName: 'Andre Kusuma',   status: 'confirmed', joinedAt: daysAgo(2), confirmedAt: daysAgo(1) },
  { id: 'slot-6c', sessionId: 'session-6', userId: 'user-cahyo',  userName: 'Cahyo Wibowo',   status: 'confirmed', joinedAt: daysAgo(1), confirmedAt: daysAgo(1) },
  { id: 'slot-6d', sessionId: 'session-6', userId: 'user-bayu',   userName: 'Bayu Pratomo',   status: 'confirmed', joinedAt: hoursAgo(20), confirmedAt: hoursAgo(18) },
  { id: 'slot-6e', sessionId: 'session-6', userId: 'user-hendy',  userName: 'Hendy Wijaya',   status: 'confirmed', joinedAt: hoursAgo(12), confirmedAt: hoursAgo(10) },
  // Session 7 (open — 2 registered)
  { id: 'slot-7a', sessionId: 'session-7', userId: 'user-bayu',   userName: 'Bayu Pratomo',   status: 'registered', joinedAt: hoursAgo(10) },
  { id: 'slot-7b', sessionId: 'session-7', userId: 'user-arif',   userName: 'Arif Budiman',   status: 'registered', joinedAt: hoursAgo(4) },
];

const cashflows = [
  { id: 'cf-01', type: 'income',  category: 'Session Fee', amount: 1200000, sessionId: 'session-1', description: 'Pemasukan sesi Mabar Sabtu Sore (8 x Rp150.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(28) },
  { id: 'cf-02', type: 'expense', category: 'Court Rental', amount: 800000, sessionId: 'session-1', description: 'Sewa lapangan Genesis Padel 2 jam', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(28) },
  { id: 'cf-03', type: 'income',  category: 'Session Fee', amount: 750000,  sessionId: 'session-2', description: 'Pemasukan sesi Rabu Siang Chill (6 x Rp125.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(21) },
  { id: 'cf-04', type: 'expense', category: 'Court Rental', amount: 600000, sessionId: 'session-2', description: 'Sewa lapangan Padel Haus BSD 2 jam', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(21) },
  { id: 'cf-05', type: 'income',  category: 'Session Fee', amount: 1600000, sessionId: 'session-3', description: 'Pemasukan sesi Friday Night Smash (8 x Rp200.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(14) },
  { id: 'cf-06', type: 'expense', category: 'Court Rental', amount: 1000000, sessionId: 'session-3', description: 'Sewa lapangan The Padel Club PIK 2 jam malam', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(14) },
  { id: 'cf-07', type: 'expense', category: 'Equipment', amount: 180000,   sessionId: 'session-3', description: 'Bola padel Head Pro S (1 tabung)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(14) },
  { id: 'cf-08', type: 'income',  category: 'Session Fee', amount: 1050000, sessionId: 'session-4', description: 'Pemasukan sesi Weekend Warriors (7 x Rp150.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(7) },
  { id: 'cf-09', type: 'expense', category: 'Court Rental', amount: 800000, sessionId: 'session-4', description: 'Sewa lapangan Genesis Padel 2 jam pagi', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(7) },
  { id: 'cf-10', type: 'income',  category: 'Session Fee', amount: 1050000, sessionId: 'session-5', description: 'Pemasukan sesi Jumat Night (6 x Rp175.000, sementara)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(2) },
  { id: 'cf-11', type: 'expense', category: 'Court Rental', amount: 900000, sessionId: 'session-5', description: 'Sewa lapangan Padel Haus BSD 2 jam malam', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(2) },
  { id: 'cf-12', type: 'expense', category: 'Equipment', amount: 450000,   description: 'Stok bola padel Bullpadel Premium Pro (3 tabung)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(25) },
  { id: 'cf-13', type: 'expense', category: 'Equipment', amount: 120000,   description: 'Overgrip Babolat VS Original (pack isi 12)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(18) },
  { id: 'cf-14', type: 'expense', category: 'Equipment', amount: 350000,   description: 'Grip tape Bullpadel + vibration dampener set', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(10) },
  { id: 'cf-15', type: 'income',  category: 'Membership', amount: 800000,  description: 'Iuran bulanan komunitas Januari (8 member x Rp100.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(45) },
  { id: 'cf-16', type: 'income',  category: 'Membership', amount: 1200000, description: 'Iuran bulanan komunitas Februari (12 member x Rp100.000)', recordedBy: 'Fajar Nugroho', createdAt: daysAgo(15) },
];

const partners = [
  { id: 'partner-genesis', name: 'Genesis Padel',          category: 'Venue',      discountPercent: 10, discountDescription: 'Diskon 10% sewa lapangan untuk anggota Daddies', address: 'Jl. Jalur Sutera Barat No.15, Alam Sutera', phone: '021-29880123', isActive: true, createdAt: daysAgo(90) },
  { id: 'partner-physio',  name: 'ProFit Physiotherapy',   category: 'Kesehatan',  discountPercent: 15, discountDescription: 'Diskon 15% fisioterapi & sport massage', address: 'Ruko BSD Junction Blok A12', phone: '0812-3456-7890', isActive: true, createdAt: daysAgo(60) },
  { id: 'partner-racket',  name: 'Padel Store Indonesia',  category: 'Equipment',  discountPercent: 10, discountDescription: 'Diskon 10% semua raket & aksesoris padel', address: 'Mall Alam Sutera Lt. 2', phone: '0857-1234-5678', isActive: true, createdAt: daysAgo(45) },
  { id: 'partner-food',    name: 'Warung Sehat BSD',       category: 'F&B',        discountPercent: 20, discountDescription: 'Diskon 20% menu healthy bowl & smoothie post-game', address: 'Jl. BSD Raya Utama No.88', phone: '0821-9876-5432', isActive: true, createdAt: daysAgo(30) },
];

// ============================================================
// SEEDER
// ============================================================

async function seedCollection(name, docs) {
  const col = db.collection(name);
  const snap = await col.limit(1).get();
  if (!snap.empty) {
    console.log(`  ⏭  ${name}: already has data, skipping`);
    return;
  }
  const batch = db.batch();
  for (const doc of docs) {
    const { id, ...data } = doc;
    // Convert Date objects to Firestore Timestamps
    for (const [k, v] of Object.entries(data)) {
      if (v instanceof Date) data[k] = admin.firestore.Timestamp.fromDate(v);
    }
    batch.set(col.doc(id), data);
  }
  await batch.commit();
  console.log(`  ✅ ${name}: seeded ${docs.length} documents`);
}

async function createFirebaseAuthUsers() {
  console.log('\n👤 Creating Firebase Auth users...');
  const authUsers = [
    { uid: 'user-reza',  email: 'reza@daddiespadel.com',  password: 'daddies2024', displayName: 'Reza Rahadian'  },
    { uid: 'user-hendy', email: 'hendy@daddiespadel.com', password: 'daddies2024', displayName: 'Hendy Wijaya'   },
    { uid: 'user-bima',  email: 'bima@daddiespadel.com',  password: 'daddies2024', displayName: 'Bima Sakti'     },
    { uid: 'user-fajar', email: 'fajar@daddiespadel.com', password: 'daddies2024', displayName: 'Fajar Nugroho'  },
  ];
  for (const u of authUsers) {
    try {
      await admin.auth().createUser({ uid: u.uid, email: u.email, password: u.password, displayName: u.displayName });
      console.log(`  ✅ Created auth: ${u.email}`);
    } catch (e) {
      if (e.code === 'auth/uid-already-exists' || e.code === 'auth/email-already-exists') {
        console.log(`  ⏭  Auth exists: ${u.email}`);
      } else {
        console.warn(`  ⚠️  ${u.email}: ${e.message}`);
      }
    }
  }
}

async function main() {
  console.log('🚀 Daddies Padel — Firestore Seeder\n');
  console.log('📦 Seeding collections...');

  await seedCollection('users',     users);
  await seedCollection('venues',    venues);
  await seedCollection('sessions',  sessions);
  await seedCollection('slots',     slots);
  await seedCollection('cashflows', cashflows);
  await seedCollection('partners',  partners);

  await createFirebaseAuthUsers();

  console.log('\n✨ Done! Firestore is ready.');
  console.log('\n📋 Login credentials:');
  console.log('   Email: reza@daddiespadel.com  | Password: daddies2024  | Role: superAdmin');
  console.log('   Email: hendy@daddiespadel.com | Password: daddies2024  | Role: mimin');
  console.log('   Email: bima@daddiespadel.com  | Password: daddies2024  | Role: mimin');
  console.log('   Email: fajar@daddiespadel.com | Password: daddies2024  | Role: bendahara');
  console.log('\n⚠️  Note: Login in app still uses phone + password "daddies" for demo mode.');
  process.exit(0);
}

main().catch(e => { console.error('❌ Error:', e); process.exit(1); });
