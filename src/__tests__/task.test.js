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
      query: `mutation {
        authenticate(input:{
          email:"${email}",
          password:"${password}",
        }) {
          jwtToken
        }
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(['data', 'authenticate', 'jwtToken']);
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
  it('should be able to add a task', async () => {
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
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'createTask', 'task', 'category']);
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

  it('create another task', async () => {
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
      .set('Authorization', `Bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'createTask', 'task', 'category']);
    expect(body.data.createTask.task.category).toEqual(category);
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
});
