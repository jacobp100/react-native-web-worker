import { self } from '@jacobp100/react-native-webworker';

self.onmessage = ({ data }) => {
  self.postMessage(`Message from worker: "${data}"!`);
};
