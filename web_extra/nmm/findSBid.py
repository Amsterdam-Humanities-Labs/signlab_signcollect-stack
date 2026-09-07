import json
import mysql.connector

# Load JSON file and build a mapping from gloss to signbank_id
input_file = "/web/glosses_transformed.json"
with open(input_file, "r", encoding="utf-8") as f:
    input_data = json.load(f)

gloss_to_signbank = {}
for entry in input_data:
    # Each entry is assumed to have one key: the signbank_id,
    # and its value is a dict containing "Lemma ID Gloss: Dutch"
    for signbank_id, content in entry.items():
        gloss = content.get("Lemma ID Gloss: Dutch", "").strip()
        if gloss:
            gloss_to_signbank[gloss] = signbank_id

# Connect to the database
db_config = {
    'host': 'signlab-db',
    'user': 'user',
    'password': 'CHeZeGa85W',
    'database': 'admin_gebarenoverleg'
}
conn = mysql.connector.connect(**db_config)
cursor = conn.cursor(dictionary=True)

# Loop through nmm_data rows where signbank_id is empty
cursor.execute("""
    SELECT id, glos
    FROM nmm_data
""")
rows = cursor.fetchall()

for row in rows:
    gloss = row["glos"].strip() if row["glos"] else ""
    if gloss in gloss_to_signbank:
        new_signbank_id = gloss_to_signbank[gloss]
        cursor.execute("UPDATE nmm_data SET signbank_id = %s WHERE id = %s",
                       (new_signbank_id, row["id"]))
        # print(f"Updated id {row['id']} with signbank_id {new_signbank_id}")
    else:
        print(f"Gloss not found in JSON: {gloss}")
        cursor.execute("UPDATE nmm_data SET signbank_id = %s WHERE id = %s",
                       ("", row["id"]))

conn.commit()
cursor.close()
conn.close()
