import { View, StyleSheet, Text, TextInput, Button } from "react-native";
import { useState } from "react";
import { useRouter } from "expo-router";

export default function Register() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");

  const router = useRouter();

  const handleRegister = async () => {
    const response = await fetch("https://server-still-raindrop-7342.fly.dev/api/v1/users", {
      method: "POST",
      body: `${email}\n${password}\n${firstName}\n${lastName}`
    });

    if (response.ok) {
      router.replace("/login");
    } else {
      console.log(await response.text());
    }
  }

  return (
    <View style={styles.container}>
      <Text style={styles.registerText}>Register</Text>
      <TextInput style={styles.registerInput} placeholder="Email" onChangeText={setEmail}/>
      <TextInput style={styles.registerInput} placeholder="Password" onChangeText={setPassword}/>
      <TextInput style={styles.registerInput} placeholder="First Name" onChangeText={setFirstName}/>
      <TextInput style={styles.registerInput} placeholder="Last Name" onChangeText={setLastName}/>
      <Button style={styles.registerButton} title="Register" onPress={handleRegister}/>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center"
  },
  registerText: {
    fontSize: 26,
    marginBottom: 16
  },
  registerInput: {
    height: 40,
    borderWidth: 1,
    padding: 10,
    margin: 12
  },
  registerButton: {
    marginTop: 30
  }
})
