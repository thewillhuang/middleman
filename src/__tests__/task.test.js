import request from 'supertest';
import faker from 'faker';
import { POSTGRAPHQLCONFIG } from '../config/index';
import app from '../server';

describe('user query', () => {
  const email = faker.internet.email();
  const password = faker.internet.password();
  const firstName = faker.name.firstName();
  const lastName = faker.name.lastName();
  it('should be able to create a new user', async () => {
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
      }`,
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let jwt;
  it('should be able to get a jwt from email and password', async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${email}",
          password:"${password}",
        )
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate;
    expect(body).toHaveProperty(['data', 'authenticate']);
  });

  let id;
  it('should be able to find self using jwt', async () => {
    const payload = {
      query: `query {
        currentPerson {
            id,
            firstName,
            lastName
          }
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'currentPerson', 'id']);
    expect(body.data.currentPerson.firstName).toEqual(firstName);
    expect(body.data.currentPerson.lastName).toEqual(lastName);
    id = body.data.currentPerson.id;
  });

  const getRandomFloat = max => Math.random() * Math.floor(max);

  const longitude = getRandomFloat(180);
  const latitude = getRandomFloat(90);
  const category = 'CAR_WASH';
  let nodeId;
  it('should be able to add task1', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'createTask', 'task', 'category']);
    expect(body).toHaveProperty(['data', 'createTask', 'task', 'nodeId']);
    nodeId = body.data.createTask.task.nodeId;
    expect(body.data.createTask.task.category).toEqual(category);
  });

  let totalCount;
  it('should be able to find nearby tasks', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    totalCount = body.data.tasks.totalCount;
  });

  let nodeId2;
  it('create task2', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'createTask', 'task', 'category']);
    expect(body.data.createTask.task.category).toEqual(category);
    nodeId2 = body.data.createTask.task.nodeId;
  });

  it('tasks should be one more than before', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body.data.tasks.totalCount).toBeGreaterThan(totalCount);
  });

  it('rejects unauthroized users from making tasks', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['errors']);
  });

  it('rejects unauthroized users from seeing tasks ', async () => {
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
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['errors']);
  });

  const email2 = faker.internet.email();
  const password2 = faker.internet.password();
  const firstName2 = faker.name.firstName();
  const lastName2 = faker.name.lastName();
  it('should be able to create a new user for permission testing', async () => {
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
      }`,
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let user2Jwt;
  it('should be able to login as user2', async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${email2}",
          password:"${password2}",
        )
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    user2Jwt = body.data.authenticate;
    expect(body).toHaveProperty(['data', 'authenticate']);
  });

  const driverEmail = faker.internet.email();
  const driverPassword = faker.internet.password();
  const driverFirstName = faker.name.firstName();
  const driverLastName = faker.name.lastName();
  it('should be able to create a new driver', async () => {
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
      }`,
    };
    await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
  });

  let driverJwt;
  it('should be able to login as a driver', async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${driverEmail}",
          password:"${driverPassword}",
        )
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    driverJwt = body.data.authenticate;
    expect(body).toHaveProperty(['data', 'authenticate']);
  });

  let driverId;
  it('should be able to find driver using jwt', async () => {
    const payload = {
      query: `query {
        currentPerson {
            id,
            firstName,
            lastName
            isClient,
          }
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'currentPerson', 'id']);
    expect(body).toHaveProperty(['data', 'currentPerson', 'isClient']);
    expect(body.data.currentPerson.firstName).toEqual(driverFirstName);
    expect(body.data.currentPerson.lastName).toEqual(driverLastName);
    expect(body.data.currentPerson.isClient).toEqual(false);
    driverId = body.data.currentPerson.id;
  });

  it('driver should be able to see tasks', async () => {
    const payload = {
      query: `query {
        tasks(longitude:${longitude}, latitude: ${latitude}, taskTypes:[${category}]) {
          edges {
            node {
              id
              category
              nodeId
              status
            }
          },
          totalCount
        }
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    // console.log({ body: JSON.stringify(body), driverJwt });
    expect(body.data.tasks.totalCount).toBeGreaterThan(totalCount);
  });

  it('user2 who did not create task1 should not be able to mark task1 as closed', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId}",
          taskPatch: {
            fulfillerId: "${id}",
            status: CLOSED
          }
        }) {
          task {
            id
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['errors']);
  });

  it('user1 who created task 1 should be able to mark task 1 as closed', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId}",
          taskPatch: {
            status: CLOSED
          }
        }) {
          task {
            id
            status
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'updateTask', 'task', 'id']);
    expect(body).toHaveProperty(['data', 'updateTask', 'task', 'status']);
    // console.log({ status: body.data.updateTask.task.status });
  });

  it('driver should not be able to mark a closed job (task1) as taken', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId}",
          taskPatch: {
            fulfillerId: "${driverId}",
            status: SCHEDULED
          }
        }) {
          task {
            id
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['errors']);
  });

  it('open driver should be able to mark task2 as taken', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId2}",
          taskPatch: {
            fulfillerId: "${driverId}",
            status: SCHEDULED
          }
        }) {
          task {
            id
          }
        }
      }`,
    };

    // console.log({ payload });

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'updateTask', 'task', 'id']);
  });

  it('driver should be able to mark task2 as PENDING_APPROVAL from client', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId2}",
          taskPatch: {
            fulfillerId: "${driverId}",
            status: PENDING_APPROVAL
          }
        }) {
          task {
            id
            nodeId
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${driverJwt}`)
      .send(payload)
      .expect(200);
    // console.log({id: body.data.updateTask.task.id, nodeId:body.data.updateTask.task.nodeId, nodeId2 });
    expect(body).toHaveProperty(['data', 'updateTask', 'task', 'id']);
  });

  it('user2 should not be able to mark task2 as finished', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId2}",
          taskPatch: {
            status: FINISHED
          }
        }) {
          task {
            id
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${user2Jwt}`)
      .send(payload)
      .expect(200);
    // console.log({error: body})
    expect(body).toHaveProperty(['errors']);
  });

  it('user should be able to mark task2 as finished', async () => {
    const payload = {
      query: `mutation {
        updateTask(input: {
          nodeId: "${nodeId2}",
          taskPatch: {
            status: FINISHED
          }
        }) {
          task {
            id
          }
        }
      }`,
    };

    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'updateTask', 'task', 'id']);
  });
});
