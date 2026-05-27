import { A } from "@solidjs/router";
import { createResource, Suspense, useContext, For, type Signal } from "solid-js";
import { AuthContext, budgetApiDomain } from "../index.tsx";
import { getToken } from "../utils/token.ts";

const TransactionPage = () => {

    // Get current date
    const currentDate = new Date();
    const month = currentDate.toLocaleDateString('en-US', { month: 'long' });
    const year = currentDate.getFullYear();

    const currencies = ["CAD", "USD"];

    const currencyFormatter = new Intl.NumberFormat('en-US', {style: "currency", currency: "USD"});

    let addTransactionDialog!: HTMLDialogElement;
    let nameInput!: HTMLInputElement;
    let categoryInput!: HTMLSelectElement;
    let amountInput!: HTMLInputElement;
    let currencyInput!: HTMLSelectElement;

    const [token, setToken] = useContext(AuthContext) as Signal<string>;

    const fetchCategories = async () => {
        // Fetch new token if user refreshed the page
        if (token() === "") setToken(await getToken());

        const response = await fetch(`${budgetApiDomain}/api/v1/categories`, {
            headers: { "Authorization": `Bearer ${token()}` }
        });

        if (response.ok) {
            const buffer = await response.arrayBuffer();
            const view = new DataView(buffer);
            const decoder = new TextDecoder("utf-8");
            const categories = [];
            let index = 0;

            while (index < buffer.byteLength) {
                // Decode category id
                const categoryIdBytes = new Uint8Array(buffer, index, 22);
                const categoryId = decoder.decode(categoryIdBytes);
                index += 22;

                // Decode name
                const nameLength = view.getUint8(index);
                const nameBytes = new Uint8Array(buffer, index + 1, nameLength);
                const name = decoder.decode(nameBytes);
                index += 1 + nameLength;

                // Decode spending limit
                const spendingLimit = view.getInt32(index);
                index += 4

                // Decode currency
                const currencyIndex = view.getUint8(index);
                index += 1;

                // Add transaction
                categories.push({
                    "category_id": categoryId,
                    "name": name,
                    "category": spendingLimit,
                    "currency": currencies[currencyIndex]
                });
            }

            return categories;
        } else if (response.status === 401) {
            setToken(await getToken());
            return fetchCategories();
        } else {
            return [];
        }
    }

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
                const dateBytes = new Uint8Array(buffer, index, 12);
                const dateString = decoder.decode(dateBytes);
                index += 12;

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
                const currencyIndex = view.getUint8(index);
                index += 1;

                // Add transaction
                transactions.push({
                    "transaction_id": transactionId,
                    "date": dateString,
                    "amount": amount,
                    "name": name,
                    "category": category,
                    "currency": currencies[currencyIndex]
                });
            }

            return transactions;
        } else if (response.status === 401) {
            setToken(await getToken());
        } else {
            return [];
        }
    }

    const [transactions, modifyTransactions] = createResource(fetchTransactions);

    const [categories] = createResource(fetchCategories);

    const addTransaction = async (event: Event) => {
        // Prevent refresh
        event.preventDefault();

        // Get user input
        const name = nameInput.value;
        const categoryId = categoryInput.value;
        const category = categoryInput.textContent;
        const amount = parseInt(amountInput.value);
        const currency_index = parseInt(currencyInput.value);

        const encoder = new TextEncoder();
        const nameBytes = new Uint8Array(encoder.encode(name).buffer);
        const categoryIdBytes = new Uint8Array(encoder.encode(categoryId).buffer);

        // Construct request body
        const totalLength = 4 + 1 + 22 + name.length;
        const combinedBuffer = new Uint8Array(totalLength);
        const dataView = new DataView(combinedBuffer.buffer);

        dataView.setInt32(0, amount, false);
        combinedBuffer[4] = currency_index;
        combinedBuffer.set(categoryIdBytes, 5);
        combinedBuffer.set(nameBytes, 27);

        // Add transaction
        const response = await fetch(`${budgetApiDomain}/api/v1/transactions`, {
          method: "POST",
          headers: { "Authorization": `Bearer ${token()}` },
          body: combinedBuffer.buffer
        });

        if (response.ok) {
            // Add newly created transaction to the UI
            const now = new Date();
            const newTransaction = {
                "transaction_id": await response.text(),
                "date": now.toLocaleDateString("en-US", { month: "long", day: "2-digit", year: "numeric" }),
                "amount": amount,
                "name": name,
                "category": category,
                "currency": currencies[currency_index]
            }
            modifyTransactions.mutate([newTransaction, ...transactions()!])

            // Close dialog upon success
            addTransactionDialog.close();
        } else if (response.status === 401) {
            setToken(await getToken());
            await addTransaction(event);
        }
    }

    return (
        <div class="flex flex-col w-screen h-screen">
            <div class="flex items-center w-screen h-1/8 border-b-2">
                <h1 class="p-6 text-2xl"><A href="/">Budget App</A></h1>
            </div>
            <div class="flex w-screen h-7/8">
                <div class="flex flex-col items-center w-1/6 border-r-2">
                    <A href="/" class="text-2xl mt-12 m-6">Home</A>
                    <A href="/transactions" class="text-2xl font-medium m-6">Transactions</A>
                    <A href="/analytics" class="text-2xl m-6">Analytics</A>
                </div>
                <div class="flex flex-col items-center w-5/6 p-12">
                    <div class="flex w-9/10 justify-start m-5">
                        <h1 class="text-3xl font-medium">Transactions</h1>
                    </div>
                    <div class="flex items-center justify-between w-9/10 m-8">
                        <h2 class="text-2xl">{month} {year}</h2>
                        <button class="cursor-pointer p-2 border" command="show-modal" commandfor="add-transaction">Add Transaction</button>
                    </div>
                    <Suspense>
                        <table class="w-9/10 border-x border-t">
                            <thead>
                                <tr class="border-b h-10">
                                    <th class="text-left pl-2">Date</th>
                                    <th class="text-left">Description</th>
                                    <th class="text-left">Amount</th>
                                </tr>
                            </thead>
                            <tbody>
                                <For each={transactions()}>
                                    {(transaction) => (
                                        <tr class="border-b h-10">
                                            <td class="pl-2">{transaction.date}</td>
                                            <td>{transaction.name}</td>
                                            <td>{currencyFormatter.format(transaction.amount / 100)}</td>
                                        </tr>
                                    )}
                                </For>
                            </tbody>
                        </table>
                    </Suspense>
                </div>
            </div>
            <dialog ref={addTransactionDialog} id="add-transaction" style="width: 40rem; height: 20rem" class="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 border">
                <button class="cursor-pointer absolute top-4 right-4" command="close" commandfor="add-transaction">Close</button>
                <form onSubmit={addTransaction} class="flex flex-col items-center">
                    <div class="flex justify-between mt-18 mb-6" style="width: 32rem">
                        <input ref={nameInput} name="transactionName" class="border p-1" placeholder="Name" required/>
                        <select ref={categoryInput} name="category" class="border" required>
                            <For each={categories()}>
                                {(category) => (
                                    <option value={category.category_id}>{category.name}</option>
                                )}
                            </For>
                        </select>
                    </div>
                    <div class="flex justify-between my-6" style="width: 32rem">
                        <input ref={amountInput} name="amount" type="number" min="0" class="border p-1" placeholder="Amount" required/>
                        <select ref={currencyInput} name="currency" class="border" required>
                            <For each={currencies}>
                                {(currency, index) => (
                                    <option value={index()}>{currency}</option>
                                )}
                            </For>
                        </select>
                    </div>
                    <button class="cursor-pointer border p-2 mt-6">Add Transaction</button>
                </form>
            </dialog>
        </div>
    )
}

export default TransactionPage;
