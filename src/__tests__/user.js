import request from 'supertest';
import faker from 'faker';
import app from '../server';

describe('user query', () => {
  const email = faker.internet.email();
  const password = faker.internet.password();
  it('should be able to create a new user', async () => {
    const payload = {
      query: `mutation {
        registerPerson(input:{
          firstName:"${faker.name.firstName()}",
          lastName:"${faker.name.lastName()}",
          email:"${email}",
          password:"${password}",
        }) {
          clientMutationId
        }
      }`,
    };
    await request(app)
      .post('/')
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
      .post('/')
      .send(payload)
      .expect(200);
    jwt = body.data.authenticate.jwtToken;
    expect(body).toHaveProperty(['data', 'authenticate', 'jwtToken']);
  });
  it('should be able to find self from jwt', async () => {
    const payload = {
      query: `query {
        currentPerson {
            id
          }
      }`,
    };
    const { body } = await request(app)
      .post('/')
      .set('Authorization', `bearer ${jwt}`)
      .send(payload)
      .expect(200);
    expect(body).toHaveProperty(['data', 'currentPerson', 'id']);
  });
});
