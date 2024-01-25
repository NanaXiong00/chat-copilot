export { };

declare global {
    interface Window {
        ENV_CONFIG: {
            REACT_APP_BACKEND_URI: string;
            REACT_APP_APPLICATIONINSIGHTS_CONNECTION_STRING: string;
        }
    }
}
