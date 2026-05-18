import { query, redirect } from "@solidjs/router";
import { budgetApiDomain } from "../index.tsx"

export const getToken = query(async () => {
    const response = await fetch(`${budgetApiDomain}/api/v1/users/token`, {
        credentials: "include"
    });

    if (response.ok) {
        return await response.text();
    } else {
        throw redirect("/login");
    }
}, "token");
