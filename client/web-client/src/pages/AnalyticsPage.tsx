import { A } from "@solidjs/router";
import { useContext, type Signal, For } from "solid-js";
import { AuthContext, budgetApiDomain } from "../index.tsx";
import { getToken } from "../utils/token.ts";

const AnalyticsPage = () => {

    const [token, setToken] = useContext(AuthContext) as Signal<string>;
    const currencies = ["CAD", "USD"];

    let addCategoryDialog!: HTMLDialogElement;
    let nameInput!: HTMLInputElement;
    let spendingLimitInput!: HTMLInputElement;
    let currencyInput!: HTMLSelectElement;

    const fetchCategories = async () => {
        // Fetch new token if user refreshed the page
        if (token() === "") setToken(await getToken());

        const response = await fetch(`${budgetApiDomain}/api/v1/transactions`, {
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

    const addCategory = async (event: Event) => {
        // Prevent refresh
        event.preventDefault();

        // Get user input
        const name = nameInput.value;
        const spendingLimit = parseInt(spendingLimitInput.value);
        const currency_index = parseInt(currencyInput.value);

        const encoder = new TextEncoder();
        const nameBytes = new Uint8Array(encoder.encode(name).buffer);

        // Construct request body
        const totalLength = 4 + 1 + name.length;
        const combinedBuffer = new Uint8Array(totalLength);
        const dataView = new DataView(combinedBuffer.buffer);

        dataView.setInt32(0, spendingLimit, false);
        combinedBuffer[4] = currency_index;
        combinedBuffer.set(nameBytes, 5);

        // Add category
        const response = await fetch(`${budgetApiDomain}/api/v1/categories`, {
            method: "POST",
            headers: { "Authorization": `Bearer ${token()}` },
            body: combinedBuffer.buffer
        });

        if (response.ok) {
            // Close dialog upon success
            addCategoryDialog.close();
        } else if (response.status === 401) {
            setToken(await getToken());
            await addCategory(event);
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
                    <A href="/transactions" class="text-2xl m-6">Transactions</A>
                    <A href="/analytics" class="text-2xl font-medium m-6">Analytics</A>
                </div>
                <div class="flex flex-col items-center w-5/6 p-12">
                    <div class="flex w-9/10 justify-start m-5">
                        <h1 class="text-3xl font-medium">Analytics</h1>
                    </div>
                    <button class="cursor-pointer p-2 border" command="show-modal" commandfor="add-category">Add Category</button>
                </div>
            </div>
            <dialog ref={addCategoryDialog} id="add-category" style="width: 40rem; height: 16rem" class="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 border">
                <button class="cursor-pointer absolute top-4 right-4" command="close" commandfor="add-category">Close</button>
                <form onSubmit={addCategory} class="flex flex-col items-center">
                    <div class="flex flex-row mt-18 my-6">
                        <input ref={nameInput} name="categoryName" class="border p-1" placeholder="Name" required/>
                        <input ref={spendingLimitInput} name="spendingLimit" type="number" min="0" class="border p-1 w-36 mx-8" placeholder="Spending Limit" required/>
                        <select ref={currencyInput} name="currency" class="border" required>
                            <For each={currencies}>
                                {(currency, index) => (
                                    <option value={index()}>{currency}</option>
                                )}
                            </For>
                        </select>
                    </div>
                    <button class="cursor-pointer border p-2 mt-6">Add Category</button>
                </form>
            </dialog>
        </div>
    )
}

export default AnalyticsPage;
