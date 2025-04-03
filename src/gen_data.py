import csv
import random
import datetime
import argparse
from faker import Faker

# Initialize Faker
fake = Faker()

# Sample data
FIRST_NAMES = [
    "Alice", "Bob", "Charlie", "David", "Eva", "Frank", "Grace", "Hank", "Ivy", "Jack",
    "Kevin", "Laura", "Mike", "Nancy", "Oscar", "Paul", "Quincy", "Rachel", "Sam", "Tina",
    "Ursula", "Victor", "Wendy", "Xander", "Yvonne", "Zack", "Amy", "Brian", "Catherine",
    "Daniel", "Emma", "Felix", "Georgia", "Henry", "Isla", "James", "Karen", "Liam", "Monica",
    "Nathan", "Olivia", "Peter", "Quinn", "Robert", "Sophie", "Tom", "Uma", "Vince", "Will",
    "Xenia", "Yasmine", "Zane"
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson",
    "Thomas", "Taylor", "Moore", "Jackson", "White"
]

COUNTRIES = ["USA", "Canada", "UK", "Australia", "Germany", "France", "Italy", "Spain", "Japan", "China",
             "India", "Brazil", "Mexico", "Russia", "South Africa", "Argentina", "Netherlands", "Sweden", "Norway", "Switzerland"]


def random_date(start_date, end_date):
    start_ts = int(datetime.datetime.strptime(start_date, "%Y-%m-%d").timestamp())
    end_ts = int(datetime.datetime.strptime(end_date, "%Y-%m-%d").timestamp())
    rand_ts = random.randint(start_ts, end_ts)
    return datetime.datetime.fromtimestamp(rand_ts).strftime("%Y-%m-%d")


def generate_email(first, last):
    domains = ["gmail.com", "yahoo.com", "hotmail.com", "outlook.com", "company.com"]
    return f"{first.lower()}.{last.lower()}{random.randint(100, 999)}@{random.choice(domains)}"


def generate_csv(output_file, max_commit, total_rows):
    print(f"Generating {total_rows:,} rows with commit every {max_commit:,} rows...")
    with open(output_file, mode="w", newline="") as file:
        writer = csv.writer(file)

        current_id = 1
        total_commits = (total_rows + max_commit - 1) // max_commit

        for batch in range(total_commits):
            writer.writerow([
                "COPY public.tb_01 (id", "customer_id", "first_name", "last_name", "email", "country",
                "phone_number", "date_birth", "purchase_date", "purchase_value",
                "num_items", "credit_score", "account_balance) FROM stdin WITH DELIMITER ',';"
            ])

            for _ in range(max_commit):
                if current_id > total_rows:
                    break

                first_name = random.choice(FIRST_NAMES)
                last_name = random.choice(LAST_NAMES)
                writer.writerow([
                    current_id,
                    random.randint(1000000, 9999999),
                    first_name,
                    last_name,
                    generate_email(first_name, last_name),
                    random.choice(COUNTRIES),
                    f"+1{random.randint(1000000000, 9999999999)}",
                    random_date("1920-01-01", "2005-12-31"),
                    random_date("2020-01-01", "2025-01-31"),
                    round(random.uniform(1, 750), 2),
                    random.randint(1, 10),
                    random.randint(300, 850),
                    round(random.uniform(0, 1_000_000), 2)
                ])
                current_id += 1

            writer.writerow(["commit;"])

            if current_id % 1_000_000 < max_commit:
                print(f"{current_id-1:,} rows generated...")

    print("Data generation complete! File:", output_file)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate CSV for PostgreSQL load test")
    parser.add_argument("-o", "--output", default="data.csv", help="Output CSV file path")
    parser.add_argument("-c", "--commit", type=int, default=1_000_000, help="Number of rows per COMMIT")
    parser.add_argument("-n", "--rows", type=int, default=100_000_000, help="Total number of rows to generate")

    args = parser.parse_args()

    generate_csv(args.output, args.commit, args.rows)
