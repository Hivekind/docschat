import React, { useState, useEffect, useRef } from "react";
import { createConsumer } from "@rails/actioncable";
import {
  useQuery,
  QueryClient,
  QueryClientProvider,
} from "@tanstack/react-query";
import { marked } from "marked";
import {
  List,
  ListItemButton,
  ListItemAvatar,
  Avatar,
  ListItemText,
  Icon,
  Tooltip,
  TextField,
  Button,
} from "@mui/material";
import { FixedSizeList } from "react-window";
import AutoSizer from "react-virtualized-auto-sizer";

const queryClient = new QueryClient();
const consumer = createConsumer();

function MeetingItem(props) {
  const { currentMeetingId } = props;
  const { isPending, error, data } = useQuery({
    queryKey: ["meetings", currentMeetingId],
    queryFn: () =>
      fetch("/meetings/" + currentMeetingId).then((res) => res.json()),
  });

  if (isPending) return "Loading...";
  if (error) return "An error has occurred: " + error.message;

  const { aiSummary, aiActionItems, entry, date, unit, id } = data;
  return (
    <div
      className="prose"
      dangerouslySetInnerHTML={{
        __html: marked.parse(aiSummary + `\n\n---\n\n` + aiActionItems),
      }}
    ></div>
  );
}

function MeetingList({ currentMeetingId, setCurrentMeetingId }) {
  const { isPending, error, data } = useQuery({
    queryKey: ["meetings"],
    queryFn: () => fetch("/meetings").then((res) => res.json()),
  });

  if (isPending) return "Loading...";
  if (error) return "An error has occurred: " + error.message;

  const renderRow = ({ index, data, style }) => {
    const meeting = data[index];
    const { id, date, unit, topic } = meeting;

    return (
      <Tooltip
        title={topic}
        placement="right-end"
        arrow
        slotProps={{
          popper: {
            modifiers: [
              {
                name: "offset",
                options: {
                  offset: [0, 16],
                },
              },
            ],
          },
        }}
      >
        <ListItemButton
          style={style}
          component="div"
          disablePadding
          selected={currentMeetingId == meeting.id}
          onClick={() => setCurrentMeetingId(id)}
        >
          <ListItemText primary={`${unit}-${id}`} secondary={date} />
        </ListItemButton>
      </Tooltip>
    );
  };

  return (
    <AutoSizer>
      {({ height, width }) => (
        <FixedSizeList
          height={height}
          width={width}
          itemCount={data.length}
          itemSize={64}
          itemData={data}
          overscanCount={5}
        >
          {renderRow}
        </FixedSizeList>
      )}
    </AutoSizer>
  );
}

function Spinner() {
  return (
    <span role="status">
      <svg
        aria-hidden="true"
        class="align-text-bottom inline w-4 h-4 text-gray-200 animate-spin dark:text-gray-600 fill-blue-600"
        viewBox="0 0 100 101"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <path
          d="M100 50.5908C100 78.2051 77.6142 100.591 50 100.591C22.3858 100.591 0 78.2051 0 50.5908C0 22.9766 22.3858 0.59082 50 0.59082C77.6142 0.59082 100 22.9766 100 50.5908ZM9.08144 50.5908C9.08144 73.1895 27.4013 91.5094 50 91.5094C72.5987 91.5094 90.9186 73.1895 90.9186 50.5908C90.9186 27.9921 72.5987 9.67226 50 9.67226C27.4013 9.67226 9.08144 27.9921 9.08144 50.5908Z"
          fill="currentColor"
        />
        <path
          d="M93.9676 39.0409C96.393 38.4038 97.8624 35.9116 97.0079 33.5539C95.2932 28.8227 92.871 24.3692 89.8167 20.348C85.8452 15.1192 80.8826 10.7238 75.2124 7.41289C69.5422 4.10194 63.2754 1.94025 56.7698 1.05124C51.7666 0.367541 46.6976 0.446843 41.7345 1.27873C39.2613 1.69328 37.813 4.19778 38.4501 6.62326C39.0873 9.04874 41.5694 10.4717 44.0505 10.1071C47.8511 9.54855 51.7191 9.52689 55.5402 10.0491C60.8642 10.7766 65.9928 12.5457 70.6331 15.2552C75.2735 17.9648 79.3347 21.5619 82.5849 25.841C84.9175 28.9121 86.7997 32.2913 88.1811 35.8758C89.083 38.2158 91.5421 39.6781 93.9676 39.0409Z"
          fill="currentFill"
        />
      </svg>
      <span class="sr-only">...</span>
    </span>
  );
}

function Messages(props) {
  const { messages, stream } = props;

  return (
    <div className="w-full">
      {messages.map((message, index) => (
        <div className="flex flex-col w-full leading-1.5 p-4 border-gray-200 bg-gray-100 rounded-e-xl rounded-es-xl dark:bg-gray-700 my-2">
          <div className="flex items-center space-x-2 rtl:space-x-reverse">
            <span className="flex text-sm font-semibold text-gray-900 dark:text-white">
              {message.role === "user" ? "You" : "Assistant"}
            </span>
          </div>
          <span
            key={index}
            dangerouslySetInnerHTML={{
              __html: marked.parse(message.content),
            }}
          ></span>
        </div>
      ))}
      {stream != "" && (
        <div className="flex flex-col w-full leading-1.5 p-4 border-gray-200 bg-gray-100 rounded-e-xl rounded-es-xl dark:bg-gray-700 my-2">
          <div className="flex items-center space-x-2 rtl:space-x-reverse">
            <span className="text-sm font-semibold text-gray-900 dark:text-white">
              Assistant <Spinner />
            </span>
          </div>
          <span
            dangerouslySetInnerHTML={{
              __html: marked.parse(stream),
            }}
          ></span>
        </div>
      )}
    </div>
  );
}

function Chat(props) {
  const { currentMeetingId, subscription, messages, setMessages, stream } =
    props;
  const [value, setValue] = useState("");
  const inputRef = useRef(null);

  useEffect(() => {
    setValue("");
    setMessages([]);
    inputRef.current.focus();
  }, [currentMeetingId]);

  const onSubmit = async (e) => {
    e.preventDefault();
    setMessages([...messages, { role: "user", content: value }]);
    subscription.send({
      action: "chat_message",
      message: value,
      meeting_id: currentMeetingId,
    });
    setValue("");
  };

  return (
    <div className="flex flex-col">
      <div className="flex">
        <Messages messages={messages} stream={stream} />
      </div>
      <form onSubmit={onSubmit}>
        <div className="flex w-max items-center absolute bottom-2 right-2">
          <TextField
            autoFocus
            size="small"
            fullWidth
            value={value}
            onChange={(e) => setValue(e.target.value)}
            ref={inputRef}
          />
          <Button>Send</Button>
        </div>
      </form>
    </div>
  );
}

function App() {
  const [currentMeetingId, setCurrentMeetingId] = useState(461);
  const [subscription, setSubscription] = useState(null);
  const [messages, setMessages] = useState([]);
  const [stream, setStream] = useState("");

  useEffect(() => {
    const sub = consumer.subscriptions.create(
      { channel: "MessagesChannel", room: `meeting` },
      {
        received: (recv) => {
          if (recv.type === "full") {
            setMessages((messages) => [
              ...messages,
              { role: "assistant", content: recv.content },
            ]);
            setStream("");
          } else if (recv.type === "partial") {
            setStream((stream) => stream + recv.content);
          }
        },
      }
    );
    setSubscription(sub);
    return () => sub.unsubscribe();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <section className="w-screen h-screen m-0 p-0 ">
        <div className="flex h-full overflow-x-hidden">
          <div className="w-1/5 overflow-y-auto bg-gray-100">
            <MeetingList
              currentMeetingId={currentMeetingId}
              setCurrentMeetingId={setCurrentMeetingId}
            />
          </div>
          <div className="w-2/5 flex h-full">
            <div className="bg-white p-4 overflow-y-auto border-r-2">
              <MeetingItem currentMeetingId={currentMeetingId} />
            </div>
          </div>
          <div className="w-2/5 flex">
            <div className="bg-white p-4 overflow-y-auto w-full max-h-[calc(100vh-4rem)] shadow">
              <Chat
                currentMeetingId={currentMeetingId}
                subscription={subscription}
                messages={messages}
                setMessages={setMessages}
                stream={stream}
              />
            </div>
          </div>
        </div>
      </section>
    </QueryClientProvider>
  );
}

// Mount and bind the React app to the DOM
import { createRoot } from "react-dom";
const domNode = document.getElementById("root");
const root = createRoot(domNode);
root.render(<App />);
