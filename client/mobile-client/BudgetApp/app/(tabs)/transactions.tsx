import { Text, View, StyleSheet } from "react-native";
import { useState, useEffect } from "react";

export default function Transactions() {
  return (
    <View style={styles.container}>
      <Text>Transactions</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center"
  }
})
