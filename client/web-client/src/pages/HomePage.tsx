import { A } from "@solidjs/router";
import { createResource, useContext, For, type Signal, createSignal, Suspense } from "solid-js"; 
import { AuthContext, budgetApiDomain } from "../index.tsx";
import { getToken } from "../utils/token.ts";

const HomePage = () => {

    const [token, setToken] = useContext(AuthContext) as Signal<string>;

    const [totalSpending, setTotalSpending] = createSignal("");

    const currencyFormatter = new Intl.NumberFormat('en-US', {style: "currency", currency: "USD"});

    const fetchSpending = async () => {
        // Fetch new token if user refreshed the page
        if (token() === "") setToken(await getToken());

        // Fetch spending information
        const spendingRequest = fetch(`${budgetApiDomain}/api/v1/transactions?sum=1`, {
            headers: { "Authorization": `Bearer ${token()}` }
        });
        const categoryRequest = await fetch(`${budgetApiDomain}/api/v1/categories`, {
            headers: { "Authorization": `Bearer ${token()}` }
        });
        let totalSpendingAccumulator = 0;

        const [spendingResponse, categoryResponse] = await Promise.all([spendingRequest, categoryRequest]);

        if (spendingResponse.ok && categoryResponse.ok) {
            // Decode spending response
            let buffer = await spendingResponse.arrayBuffer();
            let view = new DataView(buffer);
            const decoder = new TextDecoder("utf-8");
            const categorySpending = [];
            let index = 0;

            while (index < buffer.byteLength) {
                // Decode category
                const categoryLength = view.getUint8(index);
                const categoryBytes = new Uint8Array(buffer, index + 1, categoryLength);
                const category = decoder.decode(categoryBytes);
                index += 1 + categoryLength;

                // Decode amount
                const spendingValue = view.getInt32(index);
                index += 4

                // Add category spending
                categorySpending.push({
                    "category": category,
                    "spendingValue": spendingValue,
                    "spendingLimit": 0
                });

                // Add spending value to total
                totalSpendingAccumulator += spendingValue;
            }
            setTotalSpending(currencyFormatter.format(totalSpendingAccumulator / 100));

            // Decode category response
            buffer = await categoryResponse.arrayBuffer();
            view = new DataView(buffer);
            index = 0;

            while (index < buffer.byteLength) {
                // Skip over category id
                index += 22;

                // Decode name
                const categoryLength = view.getUint8(index);
                const categoryBytes = new Uint8Array(buffer, index + 1, categoryLength);
                const category = decoder.decode(categoryBytes);
                index += 1 + categoryLength;

                // Decode spending limit
                const spendingLimit = view.getInt32(index);
                index += 4

                // Skip over currency
                index += 1;

                // Search for category in category spending
                const categoryIndex = categorySpending.findIndex((x) => x.category === category)
                if (categoryIndex !== -1) {
                    categorySpending[categoryIndex].spendingLimit = spendingLimit;
                } else {
                    categorySpending.push({
                        "category": category,
                        "spendingValue": 0,
                        "spendingLimit": spendingLimit
                    });
                }
            }

            return categorySpending;
        } else if (spendingResponse.status === 401 || categoryResponse.status === 401) {
            setToken(await getToken());
            return await fetchSpending();
        } else {
            return [];
        }
    }

    const [categorySpending] = createResource(fetchSpending);

    return (
        <div class="flex flex-col">
            <div class="flex items-center w-screen h-1/8 border-b-2 fixed top-0 bg-white">
                <h1 class="p-6 text-2xl"><A href="/">Budget App</A></h1>
            </div>
            <div class="flex flex-row-reverse h-7/8">
                <div class="flex flex-col items-center w-1/6 border-r-2 fixed left-0 top-1/8 h-full">
                    <A href="/" class="text-2xl font-medium mt-12 m-6">Home</A>
                    <A href="/transactions" class="text-2xl m-6">Transactions</A>
                    <A href="/analytics" class="text-2xl m-6">Analytics</A>
                </div>
                <div class="flex flex-col items-center w-5/6 mt-22 mb-6">
                    <h2 class="text-3xl font-medium mt-16">Total Spending:</h2>
                    <Suspense fallback={<p class="text-2xl mt-6">Loading...</p>}>
                        <h3 class="text-3xl mt-6 mb-16">{totalSpending()}</h3>
                        <For each={categorySpending()}>
                            {(cs) => (
                                <div class="flex flex-col m-6 w-3/4">
                                    <div class="flex justify-between">
                                        <label class="text-xl font-medium">{cs.category}</label>
                                        <span class="text-xl">{currencyFormatter.format(cs.spendingValue / 100)} / {currencyFormatter.format(cs.spendingLimit / 100)}</span>
                                    </div>
                                    <progress class="w-full" max={cs.spendingLimit} value={cs.spendingValue.toString()}></progress>
                                </div>
                            )}
                        </For>
                    </Suspense>
                </div>
            </div>
        </div>
    )
}

export default HomePage;
