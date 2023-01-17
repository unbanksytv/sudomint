import { Button } from 'components/Button/Button'
import { AppPage, Layout } from '^@components'
import { Permissions } from '^@services/permissions'
import { stake } from '^@services/routes'

import Image from 'next/image'
import Link from 'next/link'

const Home = () => (
  <Layout hideSidebar>
    <div className="flex flex-col justify-center items-center h-full relative">
      <div className="md:w-200 text-center z-10">
        <h1 className="text-6xl leading-none font-extrabold tracking-tight text-white">
          Aloha,
        </h1>
        <h2 className="text-6xl leading-none font-extrabold tracking-tight text-dark-pink-100">
          Aloha
        </h2>
        <p className="text-xl leading-7 font-normal text-white">
          Anon.
        </p>
        <div className="flex w-full justify-center mt-4">
          <Link href={stake}>
            <Button text="Enter app" className="mr-4" />
          </Link>
          <Button text="Docs" variant="secondary" />
        </div>
      </div>
      <div className="md:absolute md:bottom-2 md:right-10">
        <Image src="/images/bunny.svg" height={550} width={550} />
      </div>
    </div>
  </Layout>
)

export default AppPage(Home, { permission: Permissions.PUBLIC })
