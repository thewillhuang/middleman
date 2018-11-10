import request from "supertest";
import faker from "faker";
import { POSTGRAPHQLCONFIG } from "../config/index";
import app from "../server";

describe("task query", () => {
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
      query: `mutation {
        authenticate(input:{
          email:"${email}",
          password:"${password}",
        }) {
          jwtToken
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let id;
  let userNodeId;
  it("should be able to find self using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id
            firstName
            lastName
            nodeId
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
    id = body.data.currentPerson.id;
    userNodeId = body.data.currentPerson.nodeId;
  });

  const getRandomFloat = max => Math.random() * Math.floor(max);

  const longitude = getRandomFloat(180);
  const latitude = getRandomFloat(90);
  const category = "CAR_WASH";
  let nodeId;
  let taskId;
  it("should be able to add task1", async () => {
    const payload = {
      query: `mutation {
        createTask(input: {task:{
          requestorId: "${id}",
          longitude: ${longitude},
          latitude: ${latitude},
          category:${category},
        }}) {
         task {
           id
           nodeId
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
    expect(body).toHaveProperty(["data", "createTask", "task", "nodeId"]);
    nodeId = body.data.createTask.task.nodeId;
    taskId = body.data.createTask.task.id;
    expect(body.data.createTask.task.category).toEqual(category);
  });

  let totalCount;
  it("should be able to find nearby tasks", async () => {
    const payload = {
      query: `query {
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
    console.log({
      "should be able to find nearby tasks": JSON.stringify(body)
    });
    totalCount = body.data.tasks.totalCount;
  });

  let nodeId2;
  let taskId2;
  it("create task2", async () => {
    const payload = {
      query: `mutation {
        createTask(input: {task:{
          requestorId: "${id}",
          longitude: ${longitude},
          latitude: ${latitude},
          category:${category},
        }}) {
         task {
           id
           category
           nodeId
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
    nodeId2 = body.data.createTask.task.nodeId;
    taskId2 = body.data.createTask.task.id;
  });

  it("tasks should be one more than before", async () => {
    const payload = {
      query: `query {
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

  it("rejects unauthroized users from making tasks", async () => {
    const payload = {
      query: `mutation {
        createTask(input: {task:{
          requestorId: "${id}",
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
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("rejects unauthroized users from seeing tasks ", async () => {
    const payload = {
      query: `query {
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
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  const email2 = faker.internet.email();
  const password2 = faker.internet.password();
  const firstName2 = faker.name.firstName();
  const lastName2 = faker.name.lastName();
  it("should be able to create a new user for permission testing", async () => {
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

  let user2Jwt;
  it("should be able to login as user2", async () => {
    const payload = {
      query: `mutation {
        authenticate(input:{
          email:"${email2}",
          password:"${password2}",
        })
        {
          jwtToken
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    user2Jwt = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let userNodeId2;
  it("should be able to find self using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id
            firstName
            lastName
            nodeId
          }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "currentPerson", "id"]);
    expect(body.data.currentPerson.firstName).toEqual(firstName2);
    expect(body.data.currentPerson.lastName).toEqual(lastName2);
    userNodeId2 = body.data.currentPerson.nodeId;
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
      query: `mutation {
        authenticate(input:{
          email:"${driverEmail}",
          password:"${driverPassword}",
        }) {
          jwtToken
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    driverJwt = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let driverId;
  let driverNodeId;
  it("should be able to find driver using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id
            nodeId
            firstName
            lastName
            isClient
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
    driverNodeId = body.data.currentPerson.nodeId;
  });

  const driverEmail2 = faker.internet.email();
  const driverPassword2 = faker.internet.password();
  const driverFirstName2 = faker.name.firstName();
  const driverLastName2 = faker.name.lastName();
  it("should be able to create a new driver", async () => {
    const payload = {
      query: `mutation {
        registerPerson(input:{
          firstName:"${driverFirstName2}",
          lastName:"${driverLastName2}",
          email:"${driverEmail2}",
          password:"${driverPassword2}",
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

  let driverJwt2;
  it("should be able to login as a driver", async () => {
    const payload = {
      query: `mutation {
        authenticate(input: {
          email:"${driverEmail2}",
          password:"${driverPassword2}",
        }) {
          jwtToken
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    driverJwt2 = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(["data", "authenticate"]);
  });

  let driverId2;
  let driverNodeId2;
  it("should be able to find driver using jwt", async () => {
    const payload = {
      query: `query {
        currentPerson {
            id
            firstName
            lastName
            isClient
            nodeId
          }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt2}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "currentPerson", "id"]);
    expect(body).toHaveProperty(["data", "currentPerson", "isClient"]);
    expect(body.data.currentPerson.firstName).toEqual(driverFirstName2);
    expect(body.data.currentPerson.lastName).toEqual(driverLastName2);
    expect(body.data.currentPerson.isClient).toEqual(false);
    driverId2 = body.data.currentPerson.id;
    driverNodeId2 = body.data.currentPerson.nodeId;
  });

  let cursor;
  let expectedCursor;
  it("driver should be able to see tasks", async () => {
    const payload = {
      query: `query {
        tasks(longitude:${longitude}, latitude: ${latitude}, taskTypes:[${category}]) {
          edges {
            cursor
            node {
              id
              category
              nodeId
              status
            }
          },
          totalCount
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    cursor = body.data.tasks.edges[0].cursor;
    expectedCursor = body.data.tasks.edges[1].cursor;
    expect(body.data.tasks.totalCount).toBeGreaterThan(totalCount);
  });

  it("driver should be able to paginate tasks", async () => {
    const payload = {
      query: `query {
        tasks(longitude:${longitude}, latitude: ${latitude}, taskTypes:[${category}], first:1, after:"${cursor}") {
          edges {
            cursor
            node {
              id
              category
              nodeId
              status
            }
          },
          totalCount
        }
      }`
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body.data.tasks.edges[0].cursor).toBe(expectedCursor);
    expect(body.data.tasks.totalCount).toBeGreaterThan(totalCount);
  });

  it("user2 who did not create task1 should not be able to mark task1 as closed", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: CLOSED
        }) {
          task {
            id
            status
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("user1 who created task 1 should be able to mark task 1 as closed", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: CLOSED
        }) {
          task {
            id
            status
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
    expect(body).toHaveProperty(["data", "updateTask", "task", "status"]);
  });

  it("driver should not be able to mark a closed job (task1) as taken", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId}",
          newTaskStatus: SCHEDULED
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("user should not be able to mark task2 as finished when its not pending", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
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
    expect(body).toHaveProperty(["errors"]);
  });

  it("open driver should be able to mark task2 as taken", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
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
          taskId: "${taskId2}",
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

  it("driver should not be able to mark task2 as FINISHED for client", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
          newTaskStatus: FINISHED
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
    expect(body).toHaveProperty(["errors"]);
  });

  it("user2 should not be able to mark task2 as finished", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
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
      .set("Authorization", `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("user should be able to mark task2 as finished", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
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

  it("driver should not be able to mark a finished job (task2) as taken", async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          taskId: "${taskId2}",
          newTaskStatus: SCHEDULED
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  // task review tests
  it("driver should not be able to add a review at all", async () => {
    const payload = {
      query: `mutation {
        addTaskReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("user2 should not be able to add a review on finished task", async () => {
    const payload = {
      query: `mutation {
        addTaskReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("user should be able to add a review on finished task", async () => {
    const payload = {
      query: `mutation {
        addTaskReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "addTaskReview", "task", "id"]);
  });

  it("user should not be able to add a review on a reviewed task", async () => {
    const payload = {
      query: `mutation {
        addTaskReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  // client review tests
  // ==========================================================

  it("user should not be able to add a review  of self at all", async () => {
    const payload = {
      query: `mutation {
        addClientReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("driver2 should not be able to add a client review on finished task", async () => {
    const payload = {
      query: `mutation {
        addClientReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt2}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("driver should be able to add a review on finished task", async () => {
    const payload = {
      query: `mutation {
        addClientReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "addClientReview", "task", "id"]);
  });

  it("driver should not be able to add a review on a reviewed task", async () => {
    const payload = {
      query: `mutation {
        addClientReview(input: {
          newTaskId: "${taskId2}",
          newRating: 1
        }) {
          task {
            status
            id
            fulfillerId
          }
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["errors"]);
  });

  it("driver 2 should not have a rating", async () => {
    const payload = {
      query: `query {
        person(nodeId: "${driverNodeId2}") {
          rating
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "person", "rating"]);
    expect(body.data.person.rating).toBe(null);
  });

  it("driver 1 should have a rating", async () => {
    const payload = {
      query: `query {
        person(nodeId: "${driverNodeId}") {
          rating
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "person", "rating"]);
    expect(parseInt(body.data.person.rating)).toBe(1);
  });

  it("user 1 should have a rating", async () => {
    const payload = {
      query: `query {
        person(nodeId: "${userNodeId}") {
          rating
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "person", "rating"]);
    expect(parseInt(body.data.person.rating)).toBe(1);
  });

  it("user 2 should not have a rating", async () => {
    const payload = {
      query: `query {
        person(nodeId: "${userNodeId2}") {
          rating
        }
      }`
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set("Authorization", `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(["data", "person", "rating"]);
    expect(body.data.person.rating).toBe(null);
  });
});
