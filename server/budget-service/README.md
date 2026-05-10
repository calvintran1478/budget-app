# Getting Started

Install Crystal as per your operating system if it is not installed already: https://crystal-lang.org/install/.

In addition, ensure you have access to a running PostgreSQL database.

## Building Dependencies

Navigate to the src directory and run the following command to install the dependencies.
```bash
shards install
```

## Setting up Environment Variables

In the src directory create a .env file with the following contents.
```
DB_CONN=<db_conn>
BCRYPT_COST=<bcrypt_cost>
API_SECRET=<api_secret>
ACCESS_TOKEN_MINUTE_LIFESPAN=<access_token_lifespan>
```
DB_CONN should be a connection string to your PostgreSQL database. The API secret should be a string only known by you (the one running the server), and is used for authentication purposes. If the server is made publicly available this should be sufficiently long and hard to guess (for example, a random string of 24 or more characters).

The bcrypt cost determines the cost of hashing user passwords. Larger values are more secure, but come with the tradeoff of slower logins. A standard default choice is 11, but this can be adjusted as needed.

The access token minute lifespan should be set to a small value (say 10-15 minutes). The value of this variable should be a positive integer.

## Database Table Setup

Before starting the server for the first time you will need to create the database tables. This can be done using the following command in the budget-service directory:
```bash
crystal src/setup.cr
```

## Starting the Server

You can start the server by running the following command in the budget-service directory:
```bash
crystal src/server.cr
```
Alternatively, you can compile the server ahead of time and start the server by running it as an executable.
```bash
crystal build src/server.cr
./server
```
If you want to optimize for performance, you can compile the server using the --release flag. However, compiling will take a bit longer.
```bash
crystal build --release src/server.cr
./server
```
