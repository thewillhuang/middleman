import request from "supertest";
import faker from "faker";
import { POSTGRAPHQLCONFIG } from "../config/index";
import app from "../server";

describe("comment query", () => {
  const email = faker.internet.email();
  const password = faker.internet.password();
  const firstName = faker.name.firstName();
  const lastName = faker.name.lastName();
  it("should be able to create a new user", async () => {
    const payload = {
      query: `mutation {
        registerPerson(input:{
          firstName:"${firstName}",
          lastName:"${lastName}",
          email:"${email}",
          password:"${password}",
          isClient: true
        }) {
          clientMutationId
        }
      }`
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let jwt;
  it("should be able to get a jwt from email and password", async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${email}",
          password:"${password}",
        )
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let userId;
  it("should be able to find self using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id,
            firstName,
            lastName
          }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "currentPerson", "id"]);
    expect(body.data.currentPerson.firstName).toEqual(firstName);
    expect(body.data.currentPerson.lastName).toEqual(lastName);
    userId = body.data.currentPerson.id;
  });

  const email2 = faker.internet.email();
  const password2 = faker.internet.password();
  const firstName2 = faker.name.firstName();
  const lastName2 = faker.name.lastName();
  it("should be able to create a new user", async () => {
    const payload = {
      query: `mutation {
        registerPerson(input:{
          firstName:"${firstName2}",
          lastName:"${lastName2}",
          email:"${email2}",
          password:"${password2}",
          isClient: true
        }) {
          clientMutationId
        }
      }`
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let jwt2;
  it("should be able to get a jwt from email and password", async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${email2}",
          password:"${password2}",
        )
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "authenticate"]);
    jwt2 = body.data.authenticate;
  });

  let userId2;
  it("should be able to find self using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id,
            firstName,
            lastName
          }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt2}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "currentPerson", "id"]);
    expect(body.data.currentPerson.firstName).toEqual(firstName2);
    expect(body.data.currentPerson.lastName).toEqual(lastName2);
    userId2 = body.data.currentPerson.id;
  });

  const getRandomFloat = max => Math.random() * Math.floor(max);
  const longitude = getRandomFloat(180);
  const latitude = getRandomFloat(90);
  const category = "CAR_WASH";
  let taskId;
  it("should be able to add a task", async () => {
    const payload = {
      query: `mutation {
        createTask(input: {task:{
          requestorId: "${userId}",
          longitude: ${longitude},
          latitude: ${latitude},
          category:${category},
        }}) {
         task {
           id
           category
         }
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "createTask", "task", "category"]);
    expect(body.data.createTask.task.category).toEqual(category);
    taskId = body.data.createTask.task.id;
  });

  const driverEmail = faker.internet.email();
  const driverPassword = faker.internet.password();
  const driverFirstName = faker.name.firstName();
  const driverLastName = faker.name.lastName();
  it("should be able to create a new driver", async () => {
    const payload = {
      query: `mutation {
        registerPerson(input:{
          firstName:"${driverFirstName}",
          lastName:"${driverLastName}",
          email:"${driverEmail}",
          password:"${driverPassword}",
          isClient: false
        }) {
          clientMutationId
        }
      }`
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let driverJwt;
  it("should be able to login as a driver", async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${driverEmail}",
          password:"${driverPassword}",
        )
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    driverJwt = body.data.authenticate;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let driverId;
  it("should be able to find driver using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id,
            firstName,
            lastName
            isClient,
          }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "currentPerson", "id"]);
    expect(body).toHaveProperty(["data", "currentPerson", "isClient"]);
    expect(body.data.currentPerson.firstName).toEqual(driverFirstName);
    expect(body.data.currentPerson.lastName).toEqual(driverLastName);
    expect(body.data.currentPerson.isClient).toEqual(false);
    driverId = body.data.currentPerson.id;
  });

  it("open driver should be able to mark task2 as taken", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: SCHEDULED
        }) {
          task {
            id
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "updateTask", "task", "id"]);
  });

  it("driver should be able to mark task2 as PENDING for client", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: PENDING
        }) {
          task {
            id
            nodeId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "updateTask", "task", "id"]);
  });

  it("user should be able to mark task2 as finished", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: FINISHED
        }) {
          task {
            id
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "updateTask", "task", "id"]);
  });

  const commentary = faker.lorem.paragraph();
  it("should allow users to add comment in regards to a task", async () => {
    const payload = {
      query: `mutation {
        createComment(input: {
          comment: {
            commentary: "${commentary}"
            personId: "${userId}"
          }
        })
        tasks(longitude:${longitude}, latitude: ${latitude}, taskTypes:[${category}]) {
          edges {
            node {
              id
              category
            }
          },
          totalCount
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body.data.tasks.totalCount).toBeGreaterThan(totalCount);
  });
});
