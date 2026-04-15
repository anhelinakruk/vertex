FROM surrealdb/surrealdb:latest

COPY ./fixtures /fixtures

CMD ["start"]