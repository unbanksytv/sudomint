import { ConnectWallet } from "@thirdweb-dev/react";
import type { NextPage } from "next";
import styles from "../styles/Home.module.css";

const Home: NextPage = () => {
  return (
    <div className={styles.container}>
      <main className={styles.main}>
        <h1 className={styles.title}>
          ...<a href="http://livethelife.tv/">LTL</a>...
        </h1>

        <p className={styles.description}>
          Get started by configuring your desired network in{" "}
          <code className={styles.code}>pages/_app.tsx</code>, then modify the{" "}
          <code className={styles.code}>pages/index.tsx</code> file!
        </p>

        <div className={styles.connect}>
          <ConnectWallet />
        </div>

        <div className={styles.grid}>
          <a href="https://livethelife.tv/" className={styles.card}>
            <h2>Live &rarr;</h2>
            <p>
            </p>
          </a>

          <a href="https://livethelife.tv/" className={styles.card}>
            <h2>The &rarr;</h2>
            <p>
            </p>
          </a>

          <a
            href="https://livethelife.tv/"
            className={styles.card}
          >
            <h2>Life &rarr;</h2>
            <p>
            </p>
          </a>
        </div>
      </main>
    </div>
  );
};

export default Home;
