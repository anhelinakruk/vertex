FROM surrealdb/surrealdb:latest

COPY ./fixtures /fixtures

CMD ["start", "--bind", "0.0.0.0:8000", "--user", "root", "--pass", "root"]