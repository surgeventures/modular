# Foo Umbrella

Uses `modular` package for:

- declaring area contracts as behaviours with owner and mutability indication
- making cross-area calls via declared & compile-time resolved references to contracts
- mocking cross-area calls without repeating a list of mocked in each umbrella sub-app

Test if modular application compiles without warnings and if tests pass regardless of from which
umbrella app (or from root) they're executed:

    ./test_all.sh
