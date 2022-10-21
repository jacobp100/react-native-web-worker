import { self } from 'react-native-webworker';

self.onmessage = ({ data }) => {
  self.postMessage(`Message from worker: "${data}"!`);
};
