import { A } from "@solidjs/router";

const HomePage = () => {
    return (
        <div class="flex flex-col w-screen h-screen">
            <div class="flex items-center w-screen h-1/8 border-b-2">
                <h1 class="p-6 text-2xl"><A href="/">Budget App</A></h1>
            </div>
            <div class="flex w-screen h-7/8">
                <div class="flex flex-col items-center w-1/6 border-r-2">
                    <A href="/" class="text-2xl font-medium mt-12 m-6">Home</A>
                    <A href="/transactions" class="text-2xl m-6">Transactions</A>
                    <A href="/analytics" class="text-2xl m-6">Analytics</A>
                </div>
                <div class="flex w-5/6">
                </div>
            </div>
        </div>
    )
}

export default HomePage;
