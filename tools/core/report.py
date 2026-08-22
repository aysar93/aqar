def top(result, limit=10):

    return sorted(
        result.items(),
        key=lambda x: x[1],
        reverse=True,
    )[:limit]


def total(result):

    return sum(result.values())


def print_table(title, result):

    print()
    print("=" * 50)
    print(title)
    print("=" * 50)

    print(f"Total : {total(result)}")
    print()

    for file, count in top(result):

        print(f"{count:>4}  {file}")