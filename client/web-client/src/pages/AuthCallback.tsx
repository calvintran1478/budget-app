import { onMount } from "solid-js"
import { useNavigate } from "@solidjs/router"
import { AuthContext } from "../index.tsx"; 
import {useContext} from "solid-js";
import type { Signal } from "solid-js";

const AuthCallback = () => {
  const navigate = useNavigate()
  const [_, setToken] = useContext(AuthContext) as Signal<string>;

  onMount(() => {
    const params = new URLSearchParams(window.location.search)
    const token = params.get("token")
    if (token) {
      setToken(token)
      navigate("/")
    } else {
      console.log("hi")
    }
  })

  return <p>Logging you in...</p>
}

export default AuthCallback