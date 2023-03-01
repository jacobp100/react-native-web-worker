self.onmessage = ({ data }) => {
  self.postMessage(`Message from worker: "${data}"!`);
};
