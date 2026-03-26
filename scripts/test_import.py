import pjsua2


def main() -> None:
    endpoint = pjsua2.Endpoint()
    assert endpoint is not None


if __name__ == "__main__":
    main()
