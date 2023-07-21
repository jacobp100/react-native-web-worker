import React, { useEffect, useRef, useState } from 'react';
import {
  Button,
  SafeAreaView,
  StyleSheet,
  Text,
  ScrollView,
} from 'react-native';
import { WebWorker } from '@jacobp100/react-native-webworker';

export default () => {
  const [messages, setMessages] = useState<string[]>([]);
  const [environment, setEnvironment] = useState<'light' | 'react-native'>(
    'light'
  );
  const workerRef = useRef<WebWorker>();

  useEffect(() => {
    console.log(`Create worker: ${environment}`);
    const worker = new WebWorker(`./worker-${environment}.js`, { environment });
    worker.onmessage = ({ data }) => {
      setMessages((m) => [...m, data]);
    };
    workerRef.current = worker;
    return () => {
      console.log(`Terminate worker: ${environment}`);
      worker.terminate();
      workerRef.current = undefined;
    };
  }, [environment]);

  const postMessage = () => {
    workerRef.current!.postMessage(`Message ${messages.length + 1}`);
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView contentContainerStyle={styles.contentContainer}>
        <Text style={styles.welcome}>Welcome to React Native WebWorker!</Text>

        <Text>Environment: {environment}</Text>
        <Button
          title="Use Light Envonment"
          onPress={() => setEnvironment('light')}
        />
        <Button
          title="Use React-Native Envonment"
          onPress={() => setEnvironment('react-native')}
        />

        <Button title="Send Message To Worker" onPress={postMessage} />

        <Text style={styles.messages}>Messages:</Text>
        {messages.map((message, i) => (
          <Text key={i} style={styles.message}>
            {message}
          </Text>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  contentContainer: {
    padding: 20,
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    marginTop: 10,
    marginBottom: 20,
  },
  messages: {
    fontSize: 14,
    fontWeight: '600',
    marginTop: 20,
    marginBottom: 3,
  },
  message: {
    fontSize: 11,
    fontVariant: ['tabular-nums'],
  },
});
