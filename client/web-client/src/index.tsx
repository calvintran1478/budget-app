import { lazy, createContext, createSignal } from "solid-js";
import { render } from "solid-js/web";
import { Router, Route } from "@solidjs/router";
import "uno.css";

const HomePage = lazy(() => import("./pages/HomePage"));
const RegisterPage = lazy(() => import("./pages/RegisterPage"));
const LoginPage = lazy(() => import("./pages/LoginPage"));

export const budgetApiDomain = import.meta.env.PROD ? "https://server-still-raindrop-7342.fly.dev" : "http://localhost:8080";
export const scanApiDomain = import.meta.env.PROD ? "https://scan-service.fly.dev" : "http://localhost:8000";
export const AuthContext = createContext();

function AuthProvider(props: any) {
    const [token, setToken] = createSignal("");

    return (
        <AuthContext.Provider value={[token, setToken]}>
            {props.children}
        </AuthContext.Provider>
    )
}

render(
    () => (
        <Router root={(props) => <AuthProvider>{props.children}</AuthProvider>}>
            <Route path="/" component={HomePage}/>
            <Route path="/register" component={RegisterPage}/>
            <Route path="/login" component={LoginPage}/>
        </Router>
    ),
    document.getElementById("root")!
);
