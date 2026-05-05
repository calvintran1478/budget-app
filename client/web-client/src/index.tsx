import { lazy } from "solid-js";
import { render } from "solid-js/web";
import { Router, Route } from "@solidjs/router";
import "uno.css";

const RegisterPage = lazy(() => import("./pages/RegisterPage"));

render(
    () => (
        <Router>
            <Route path="/register" component={RegisterPage}/>
        </Router>
    ),
    document.getElementById("root")!
);
