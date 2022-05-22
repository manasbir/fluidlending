import Button from './components/Button';

export default function Home() {
  const inputStyle = {
    height: 30,
    width: 300
  };

  return (
    <div style={{
      display: 'flex',
      height: '100vh',
      flexDirection: 'column'
    }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <h1 style={{
          width: '100%',
          textAlign: 'center'
        }}>Hack Money</h1>
      </div>
      <div style={{
        display: 'flex',
        justifyContent: 'flex-end',
        padding: 10
      }}> <Button style={{ height: 40 }}>Top Right</Button></div>
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        flexGrow: 1,
        justifyContent: 'center',
        gap: 5
      }} >
        <div> <label>Label 1: </label> <input type="text" style={inputStyle} /></div>
        <div> <label>Label 2:</label> <input type="text" style={inputStyle} /></div>
        <div> <label>Label 3:</label> <input type="text" style={inputStyle} /></div>
        <div> <label>Label 4:</label> <input type="text" style={inputStyle} /></div>
        <Button style={{ height: 40 }}> Center</Button>
      </div>
    </div >
  )
}
