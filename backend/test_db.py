import sqlite3
conn = sqlite3.connect('e:/gram_nirikshan/backend/app.db')
print(conn.execute('SELECT * FROM users WHERE mobile=\'7906576689\'').fetchall())
