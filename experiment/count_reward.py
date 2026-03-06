import csv

def count_reward(file_path):
    count = 0
    previous_value = None

    with open(file_path, newline='', encoding='utf-8') as csvfile:
        reader = csv.reader(csvfile)

        # Skip header
        next(reader, None)

        for row in reader:
            if len(row) < 7:
                continue

            try:
                current_value = int(row[6].strip())
            except ValueError:
                continue

            if current_value == 1 and previous_value != 1:
                count += 1

            previous_value = current_value

    return count


if __name__ == "__main__":
    import sys

    if len(sys.argv) != 2:
        print("Usage: python count_reward.py <file.csv>")
        sys.exit(1)

    result = count_reward(sys.argv[1])
    print(f"Number of reward (discounting consecutive duplicates): {result}")