import { onMount } from "solid-js"
import { useNavigate } from "@solidjs/router"
import { AuthContext } from "../index.tsx"; 
import {useContext} from "solid-js";
import type { Signal } from "solid-js";

const AuthCallback = () => {
    const navigate = useNavigate()
    const [_, setToken] = useContext(AuthContext) as Signal<string>;

    onMount(async () => {
        const res = await fetch("http://localhost:8080/api/v1/users/token", {
        method: "POST",
        credentials: "include" 
        })
        if (res.ok) {
        setToken(await res.text())
        navigate("/")
        } else {
        navigate("/login")
        }
    })
  
    return <p>Logging you in...</p>
}

export default AuthCallback