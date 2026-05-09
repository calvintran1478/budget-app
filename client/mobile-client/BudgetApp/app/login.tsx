import { View, StyleSheet, Text, TextInput, Button } from "react-native";
import { useState } from "react";
import { useRouter } from "expo-router";
import { Platform } from "react-native";
import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";

export default function Login() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

  const router = useRouter();

  const isWeb = Platform.OS === "web";

  const handleLogin = async () => {
    const response = await fetch("https://server-still-raindrop-7342.fly.dev/api/v1/users/login", {
      method: "POST",
      body: `${email}\n${password}`
    });

    if (response.ok) {
      const accessToken = await response.text();
      if (isWeb) {
        await AsyncStorage.setItem("accessToken", accessToken);
      } else {
        await SecureStore.setItemAsync("accessToken", accessToken);
      }
 
      router.replace("/");
    } else {
      console.log(await response.text());
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.loginText}>Login</Text>
      <TextInput style={styles.loginInput} placeholder="Email" onChangeText={setEmail}/>
      <TextInput style={styles.loginInput} placeholder="Password" onChangeText={setPassword}/>
      <Button style={styles.loginButton} title="Login" onPress={handleLogin}/>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center"
  },
  loginText: {
    fontSize: 26,
    marginBottom: 16
  },
  loginInput: {
    height: 40,
    borderWidth: 1,
    padding: 10,
    margin: 12
  },
  loginButton: {
    marginTop: 30
  }
})
