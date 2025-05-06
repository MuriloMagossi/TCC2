const { ApolloServer } = require('@apollo/server');
const { startStandaloneServer } = require('@apollo/server/standalone');

// Schema definition
const typeDefs = `
  type Echo {
    message: String
    timestamp: String
  }

  type Query {
    hello: String
    echo(message: String!): Echo
  }
`;

// Resolver functions
const resolvers = {
  Query: {
    hello: () => 'Hello from GraphQL!',
    echo: (_, { message }) => ({
      message,
      timestamp: new Date().toISOString()
    }),
  },
};

// Create Apollo Server
const server = new ApolloServer({
  typeDefs,
  resolvers,
});

// Start server
async function startServer() {
  const { url } = await startStandaloneServer(server, {
    listen: { port: 9000 }
  });
  
  console.log(`🚀 GraphQL server ready at ${url}`);
}

startServer(); 