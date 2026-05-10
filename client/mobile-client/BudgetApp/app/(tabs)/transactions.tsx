import { Text, View, StyleSheet, Button } from "react-native";
import { useState, useEffect } from "react";
import { Platform } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";

export default function Transactions() {
  const [transactions, setTransactions] = useState([]);

  const isWeb = Platform.OS === "web";

  const currencies = ["CAD", "USD"];

  const addTransaction = async () => {
    // Request body fields
    const amount = 200;
    const currency_index = 0;
    const name = "Coffee";
    const category = "Food and Drinks";

    const encoder = new TextEncoder();
    const nameBytes = new Uint8Array(encoder.encode(name).buffer);
    const categoryBytes = new Uint8Array(encoder.encode(category).buffer);
    const newLineByte = new Uint8Array(encoder.encode('\n').buffer);

    // Construct request body
    const totalLength = 4 + 1 + name.length + 1 + category.length;
    const combinedBuffer = new Uint8Array(totalLength);
    const dataView = new DataView(combinedBuffer.buffer);

    dataView.setInt32(0, amount, false);
    combinedBuffer[4] = currency_index;
    combinedBuffer.set(nameBytes, 5);
    combinedBuffer.set(newLineByte, 5 + name.length);
    combinedBuffer.set(categoryBytes, 6 + name.length);

    const token = isWeb ? (await AsyncStorage.getItem("accessToken")) : (await SecureStore.getItemAsync("accessToken"));
    const response = await fetch("https://server-still-raindrop-7342.fly.dev/api/v1/transactions", {
      method: "POST",
      headers: { "Authorization": `Bearer ${token}` },
      body: combinedBuffer.buffer
    });

    if (response.ok) {
      const newTransactions = [...transactions];
      const now = new Date();
      const transaction = {
        transaction_id: await response.text(),
        date: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`,
        amount: amount,
        name: name,
        category: category,
        currency: currencies[currency_index]
      }
      newTransactions.push(transaction);
      setTransactions(newTransactions);
    }
  }

  const getTransactions = async () => {
    const token = isWeb ? (await AsyncStorage.getItem("accessToken")) : (await SecureStore.getItemAsync("accessToken"));
    const response = await fetch("https://server-still-raindrop-7342.fly.dev/api/v1/transactions", {
      headers: { "Authorization": `Bearer ${token}` }
    });

    if (response.ok) {
      const buffer = await response.arrayBuffer();
      const view = new DataView(buffer);
      const decoder = new TextDecoder("utf-8");
      const _transactions = [];
      let index = 0;

      while (index < buffer.byteLength) {
        // Decode transaction id
        const transactionIDBytes = new Uint8Array(buffer, index, 22);
        const transactionID = decoder.decode(transactionIDBytes);
        index += 22;

        // Decode date
        const dateBytes = new Uint8Array(buffer, index, 10);
        const date = decoder.decode(dateBytes);
        index += 10;

        // Decode amount
        const amount = view.getInt32(index, false);
        index += 4;

        // Decode name
        const nameLength = view.getUint8(index);
        const nameBytes = new Uint8Array(buffer, index + 1, nameLength);
        const name = decoder.decode(nameBytes);
        index += 1 + nameLength;

        // Decode category
        const categoryLength = view.getUint8(index);
        const categoryBytes = new Uint8Array(buffer, index + 1, categoryLength);
        const category = decoder.decode(categoryBytes);
        index += 1 + categoryLength;

        // Decode currency
        const currencyLength = view.getUint8(index);
        const currencyBytes = new Uint8Array(buffer, index + 1, currencyLength);
        const currency = decoder.decode(currencyBytes);
        index += 1 + currencyLength;

        // Add transaction entry
        _transactions.push({
          transaction_id: transactionID,
          date: date,
          amount: amount,
          name: name,
          category: category,
          currency: currency
        });
      }
      setTransactions(_transactions);
    }
  }

  useEffect(() => {
    getTransactions();
  }, [])
  
  return (
    <View style={styles.container}>
      <Text>Transactions</Text>
      <Button title="Add Transaction" onPress={addTransaction}/>
      {transactions.map((transaction, index) => (
        <View key={transaction.transaction_id} style={styles.transactionStyle}>
          <Text>{transaction.transaction_id}</Text>
          <Text>{transaction.name}</Text>
          <Text>{transaction.date}</Text>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center"
  },
  transactionStyle: {
    borderWidth: 1
  }
})
