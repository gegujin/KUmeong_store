import * as bcrypt from 'bcrypt';

async function generateHash(password) {
  const saltRounds = 10;
  const hash = await bcrypt.hash(password, saltRounds);
  return hash;
}

async function main() {
  // 업데이트할 계정 정보
  const users = [
    { email: 'student@kku.ac.kr', password: 'password1234' },
    { email: 'rider@kku.ac.kr', password: 'password1234' },
    { email: 'buyer@kku.ac.kr', password: 'password1234' },
  ];

  console.log('-- 🔹 MySQL UPDATE statements --');
  for (const user of users) {
    const hash = await generateHash(user.password);
    console.log(
      `UPDATE users SET password_hash='${hash}' WHERE email='${user.email}';`
    );
  }
}

main().catch(console.error);