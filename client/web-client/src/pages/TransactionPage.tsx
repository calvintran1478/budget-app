import { A } from "@solidjs/router";
import { createResource, Suspense, useContext, For, type Signal } from "solid-js";
import { AuthContext, budgetApiDomain } from "../index.tsx";
import { getToken } from "../utils/token.ts";

const TransactionPage = () => {

    const [token, setToken] = useContext(AuthContext) as Signal<string>;

    const fetchTransactions = async () => {
        // Fetch new token if user refreshed the page
        if (token() === "") setToken(await getToken());
        
        const response = await fetch(`${budgetApiDomain}/api/v1/transactions`, {
            headers: { "Authorization": `Bearer ${token()}` }
        });

        if (response.ok) {
            const buffer = await response.arrayBuffer();
            const view = new DataView(buffer);
            const decoder = new TextDecoder("utf-8");
            const transactions = [];
            let index = 0;

            while (index < buffer.byteLength) {
                // Decode transaction id
                const transactionIdBytes = new Uint8Array(buffer, index, 22);
                const transactionId = decoder.decode(transactionIdBytes);
                index += 22;

                // Decode date
                const dateBytes = new Uint8Array(buffer, index, 10);
                const dateString = decoder.decode(dateBytes);
                index += 10;

                // Decode amount
                const amount = view.getInt32(index);
                index += 4

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

                // Add transaction
                transactions.push({
                    "transaction_id": transactionId,
                    "date": dateString,
                    "amount": amount,
                    "name": name,
                    "category": category,
                    "currency": currency
                });
            }

            console.log(transactions);
            return transactions;
        } else if (response.status === 401) {
            setToken(await getToken());
        } else {
            return [];
        }
    }

    const [transactions] = createResource(fetchTransactions);

    return (
        <div class="flex flex-col w-screen h-screen">
            <div class="flex items-center w-screen h-1/8 border-b-2">
                <h1 class="p-6 text-2xl"><A href="/">Budget App</A></h1>
            </div>
            <div class="flex w-screen h-7/8">
                <div class="flex flex-col items-center w-1/6 border-r-2">
                    <A href="/" class="text-2xl mt-12 m-6">Home</A>
                    <A href="/transactions" class="text-2xl font-medium m-6">Transactions</A>
                </div>
                <div class="flex flex-col items-center w-5/6 p-12">
                    <Suspense>
                        <table class="w-9/10 border-x border-t">
                            <thead>
                                <tr class="border-b">
                                    <th class="text-left">Date</th>
                                    <th class="text-left">Name</th>
                                    <th class="text-left">Amount</th>
                                </tr>
                            </thead>
                            <tbody>
                                <For each={transactions()}>
                                    {(transaction) => (
                                        <tr class="border-b h-4">
                                            <td>{transaction.date}</td>
                                            <td>{transaction.name}</td>
                                            <td>{transaction.amount}</td>
                                        </tr>
                                    )}
                                </For>
                            </tbody>
                        </table>
                    </Suspense>
                </div>
            </div>
        </div>
    )
}

export default TransactionPage;
