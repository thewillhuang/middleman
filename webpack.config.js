const webpack = require('webpack');
const UglifyJsPlugin = require('uglifyjs-webpack-plugin');

const config = {
  target: 'node',

  entry: {
    main: './src',
    makeCache: './src/makeCache.js',
  },

  node: {
    __dirname: true,
  },

  mode: 'production',

  optimization: {
    minimizer: [
      new UglifyJsPlugin({
        cache: true,
        uglifyOptions: {
          keep_fnames: true,
          output: {
            comments: false,
          },
        },
      }),
    ],
  },

  module: {
    rules: [
      {
        test: /\.js$/,
        use: {
          loader: 'babel-loader',
        },
      },
      {
        test: /\.(pem|txt|sql)$/,
        use: 'raw-loader',
      },
    ],
  },

  plugins: [
    new webpack.IgnorePlugin(/\.\/native/, /\/pg\//),
  ],

};

module.exports = config;
