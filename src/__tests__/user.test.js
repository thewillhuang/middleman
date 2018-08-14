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
  });

  it('reject wrong email or password', async () => {
    const payload = {
      query: `query {
        authenticate(
          email:"${faker.internet.email()}",
          password:"${faker.internet.password()}",
        )
      }`,
    };
    const { body } = await request(app)
      .post(POSTGRAPHQLCONFIG.graphqlRoute)
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate;
    expect(body.data.authenticate).toBe(null);
  });
});
